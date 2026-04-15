---
title: "The Prompt Injection Defence Landscape"
date: 2026-04-15
categories: ['AI Security']
tags: ['AI', 'Prompt Injection']
img_path: ""
image:
    path: "prompt-inj-banner.png"
---

Prompt injection is a class of attacks where **an adversary embeds malicious instructions into content that an LLM will process**.
As LLMs increasingly gain the ability to take complex autonomous actions on behalf of users, the consequences of a successful injection can be severe.

Defences against this class of attacks are a particularly interesting topic as they encompass multiple areas of ML and security: model alignment, fine-tuning, architectural isolation, information flow control, anomaly detection, etc.
This post gives a brief overview of the different kinds of defences.

> **A few caveats**:
> - I am trying to roughly group techniques by macro categories; in practice boundaries can be blurry and many tools use a combination of techniques.
> - This is a rapidly evolving area of research, as such I might have missed some approaches. If so, please let me know, I'd be happy to add them.
> - Expect errors, please let me know if you spot any. Refer to the primary sources as the source of truth.
> - This post doesn't discuss pros & cons of each technique, it just briefly lists them.
{: .alert .alert-info}

Finally: this is not an exhaustive list. I plan to publish soon-ish a better mapping of these techniques and relevant sources.

## Detection

Detection defences classify or evaluate inputs, model responses, reasoning traces, or agent behaviour to identify adversarial intent. 

### Input Screening

Approaches in this category directly inspect data consumed by the model to identify malicious content.

**Regex-Based** detection uses regex to find and block suspicious content. [Vigil](https://github.com/deadbits/vigil-llm)'s YARA rules are an example of this.

**VectorDB-Based** filters embed the incoming prompt with an embedding model and compute cosine similarity against a store (e.g. [ChromaDB](https://www.trychroma.com/products/chromadb)) of previously seen attack embeddings.

In **LLM-Based** detection defences a [second LLM instance](https://learnprompting.org/docs/prompt_hacking/defensive_measures/llm_eval) acts as a security gate, often given a security-focused persona.
Some detection tools such as [Rebuff](https://github.com/protectai/rebuff) use a combination of all of the above.

**Classifier-Based** approaches use a classifier, often an encoder model (e.g. BERT-family), to screen incoming content for adversarial patterns.
This approach is fairly common and used by a variety of tools: [LlamaFirewall](https://arxiv.org/abs/2505.03574), [LLM Guard](https://protectai.github.io/llm-guard/input_scanners/prompt_injection/), [Vigil](https://github.com/deadbits/vigil-llm), etc.

**Semantic Drift Detection** [consists](https://arxiv.org/abs/2601.12359) in comparing `[prompt]` embeddings vs `[prompt || <untrusted data>]` embeddings and measuring how much a potential injection shifts the semantic representation in embedding space.

**Perplexity Filters** measure how "unusual" an incoming prompt is to [block it](https://arxiv.org/abs/2309.00614). They specifically aim at *Greedy Coordinate Gradient (GCG)-like* [attacks](https://arxiv.org/abs/2307.15043), which tend to generate atypical prompts containing a lot of gibberish. 

**Known-Answer Detection** inserts a canary instruction with a pre-specified correct answer alongside untrusted content, then checks whether the model still returns that answer. If it changed, the untrusted content likely overrode the trusted instruction. More advanced variants such as [DataSentinel](https://arxiv.org/abs/2501.00218) fine-tune a dedicated detection LLM.

An intersecting research area looks at ways to "augment" the effectiveness of input detection approaches. For example, **Erase-and-check** [approaches](https://arxiv.org/abs/2309.02705) strategically remove tokens from the prompt, making potentially harmful commands easier to detect by e.g. a classifier.


### Post-Response Detection

Detection need not happen only at ingestion time. An early example of this is [Rebuff](https://github.com/protectai/rebuff)'s canary token scanner, which injects a random hex token into the system-prompt template before the LLM call, then scans the model response for that token; if it appears, the model was manipulated into leaking it.

More broadly **Output Screening** applies output-stage detection techniques to the model draft response before it is released, checking it for harmful content. This [can be](https://arxiv.org/abs/2308.07308) as simple as the model itself but in judge mode.

**Backtranslation** takes this further and [infers](https://arxiv.org/abs/2402.16459) what hidden harmful request the answer implies, then blocks it if that reconstructed request would normally be refused.

**Response Divergence Detection** (e.g. [JailGuard](https://arxiv.org/abs/2312.10766)) mutates the input in multiple ways, queries the model on each variant, and flags the original as adversarial when the resulting responses are unusually inconsistent.

### Behavioural Monitoring

A broader pattern consists in inspecting intermediate states or actions of the model and detecting divergence from the original task.

Rather than detecting harmful content, defences such as [The Task Shield](https://arxiv.org/abs/2412.16682) reframe injections as a **Task Alignment** problem: every instruction and tool call is verified to contribute to the user's stated objectives and rejected otherwise.

**Activation-Based** approaches monitor the internal hidden state of the model to detect anomalies. [TaskTracker](https://arxiv.org/abs/2406.00799) is an example: the model's internal state is monitored for abrupt changes that might indicate task drift induced by an injection.

**Memory Defences** protect against memory poisoning — attacks that insert adversarially crafted entries into the agent's persistent memory store so that future retrievals silently bias reasoning or actions.
[A-MemGuard](https://arxiv.org/abs/2510.02373) does this by comparing reasoning paths derived from related memory entries and removing those that diverge.

**Chain-of-Thought (CoT) Monitoring** consists of observing the intermediate reasoning steps of the model for misbehaviour.
An example of this is [LlamaFirewall](https://arxiv.org/abs/2505.03574)'s AlignmentCheck step which employs an LLM auditor to detect CoT drifting from the original plan.
By the way, [research](https://arxiv.org/abs/2503.11926) around this topic is a fun read, and [literature](https://arxiv.org/abs/2412.04984) covering AI attempts at stealthily bypassing this type of monitoring feels like part of a dystopian tech novel.

In **Agent Guardrails** solutions a dedicated agent interposes between the primary LLM and the environment, evaluating each proposed action against a set of safety checks before execution is permitted.
In [GuardAgent](https://arxiv.org/abs/2406.09187) a guardrail LLM generates code to verify the primary LLM's proposed action.

[MELON](https://arxiv.org/abs/2502.05174) uses a **Dual Execution** approach to detect indirect prompt injection by running the agent on two parallel execution paths: one normal, one with the user task masked out, and flags attacks when the masked run produces semantically similar tool calls to the original run.

In **Multi-Agent Anomaly Detection** the unit of analysis is the agent itself, not an individual message. Approaches such as [BlindGuard](https://arxiv.org/abs/2511.05797) train a GNN on normal agent interaction data to score each agent's semantic deviation from its peers; anomalous agents have their communication edges pruned for the remainder of the round. This is useful because in multi-agent systems a compromised agent can spread malicious influence through the communication graph.

## Sanitization

Rather than blocking an entire input when an injection is suspected, sanitization forwards a cleaned or transformed version of the data to the agent. This preserves more utility than a binary block/allow decision.

**LLM-Based Sanitization** uses a guardrail LLM to detect and remove harmful content from untrusted data before forwarding it to the backend model. [PromptArmor](https://arxiv.org/abs/2507.15219) detects the injected portion, strips it with a fuzzy-match regex, and passes clean data to the backend. A fine-tuned variant, [DataFilter](https://arxiv.org/abs/2502.04718), generates cleaned output by copying benign tokens and deleting injected imperative sentences.

**Paraphrasing** consists of routing the input through an LLM paraphraser before it reaches the target model. Since GCG-style adversarial suffixes depend on precise token sequences, rewriting the prompt in natural language destroys the attack while (hopefully) preserving the original meaning.

**Input Perturbation** is similar to paraphrasing: [SmoothLLM](https://arxiv.org/abs/2310.03684) generates N randomly character-perturbed copies of the input, queries the LLM on each, and returns a majority-vote response. Random perturbations are non-differentiable, which prevents direct gradient-based adaptive attacks.

## Prompt Massaging

Or *Prompt Engineering* as most people call it. These techniques modify the structure or wording of the prompt to make injected instructions less likely to override the intended directive.

**Instruction Reinforcement**, simply put: repeats the task instruction at the end of the prompt (sandwiching), uses explicit goal-ordering cues, or adds hand-written warnings. 

**Content Delimitation** marks or encodes untrusted input, via random sequences, XML tags, or else. This is to create an unambiguous boundary between developer instructions and external content. [Spotlighting](https://arxiv.org/abs/2403.14720) goes in this category. A [**Mixture of Encodings**](https://aclanthology.org/2025.naacl-short.21/) approach applies multiple delimiter styles simultaneously.

**Learned Prompt Patches** optimise a fixed reusable prompt fragment offline and prepend or append it to every query. [RPO](https://arxiv.org/abs/2401.17263) is an example of this.

**Self-Reasoning Defences** [instruct](https://arxiv.org/abs/2505.17089) the model to generate adversarial attack scenarios and defensive counter-strategies as a chain-of-thought prefix before producing its final reply, harnessing the model's own internal threat knowledge without any external components.

**In-Context Demonstrations** [prepend](https://arxiv.org/abs/2310.06387) a small number of `(harmful-request, safe-refusal)` example pairs to the context before each user query, steering model behaviour via in-context learning without modifying any model parameters.

## Architectural Isolation

Architectural isolation moves security guarantees at a higher system-level.

**Role Separation** (e.g. [Dual LLM](https://simonwillison.net/2023/Apr/25/dual-llm-pattern/)) splits agent execution into a Privileged LLM that plans and calls tools and a Quarantined LLM that processes untrusted content but has no tool-calling authority, so injected instructions in external data cannot trigger privileged actions.

**Plan-Then-Execute** approaches construct a complete tool-invocation plan before any external content is accessed, so injected instructions encountered at runtime cannot introduce new tool calls (e.g. [IPIGuard](https://arxiv.org/abs/2501.15145)). **Code-Then-Execute** approaches further generalise that: the LLM writes a program to solve a task, the program might call tools and quarantined LLMs, but the separation of trusted vs untrusted data is handled programmatically.
[CaMeL](https://arxiv.org/abs/2503.18813) is probably the most famous instantiation of this: the LLM writes Python scripts which are executed by a custom interpreter that tracks data provenance via capabilities and enforces security policies at tool-call time. 

**Information Flow Control** hooks the agent runtime to track how data propagates from external observations to tool-call parameters, then enforces a formal security policy to block any call whose parameters are tainted by untrusted content, without modifying the backbone LLM. [Progent](https://arxiv.org/abs/2504.11703) for example proposes a fine-grained policy framework that is dynamically updated following tool calls.

**Execution Isolation** [confines](https://arxiv.org/abs/2403.04960) each app in an agentic system to its own OS-isolated process with a dedicated LLM instance. Cross-app requests are validated externally and unexpected actions can be surfaced to the user for approval.

**Structured Queries** separate trusted instructions from untrusted data at the interface or representation level, so external content is treated as data rather than executable instructions. [StruQ](https://arxiv.org/abs/2402.06363) implements this via a specialised front-end and fine-tuning. **Instruction Authentication** is a somewhat similar idea, but it [encodes](https://arxiv.org/abs/2401.07612) authorised commands into privileged "signed" forms that the adapted model alone treats as executable, keeping plain-language commands inert even when they appear in untrusted content.

## Training

Training-based defences bake the security signal directly into model weights or learned embeddings, through an offline optimisation pass.

**Adversarial Fine-Tuning** fine-tunes the model on adversarial conflict examples paired with correct responses so the model learns to treat delimited external content as read-only data. 

**Instruction Hierarchy Training** trains the model on a privilege ordering across message roles (system > user > tool output) using synthetic aligned and misaligned examples, so conflicts are resolved in favour of the higher-privileged instruction — generalising to held-out attack types. OpenAI's models train this behaviour explicitly; an RL-based extension ([IH-Challenge](https://arxiv.org/abs/2603.10521)) further hardens the model via online adversarial conflict synthesis.

**Task-Specific Fine-Tuning** (e.g. [Jatmo](https://arxiv.org/abs/2312.04235)) distils a fixed trusted task into a non-instruction-tuned base model using only benign task examples, removing the live instruction channel that prompt injection normally overrides.

**Preference Optimisation** (e.g. [SecAlign](https://arxiv.org/abs/2410.05451)) fine-tunes with an objective that simultaneously increases the likelihood of the benign response and explicitly drives down the likelihood of the injected-instruction response.

**Embedding Optimisation** applies gradient-based optimisation to a small set of newly added token embeddings in front of a frozen model, so prepending those tokens at inference time achieves security comparable to full adversarial fine-tuning while leaving all model weights unchanged — giving deployers a clean security/utility toggle (e.g. [DefensiveToken](https://arxiv.org/abs/2501.18915)). This is somewhat similar to the *Learned Prompt Patches* approach above, but works at the embedding level.

## Proactive Deception

Rather than hardening one's own system, proactive deception seeds the attacker's environment with traps. The [CHeaT framework](https://www.usenix.org/conference/usenixsecurity25/presentation/ayzenshteyn) provides 6 tactics and 15 techniques that Cloak assets (false beliefs, invisible Unicode), deploy LLM-specific Honeytokens (readable by LLMs but invisible to humans, for attacker detection), and plant Traps (context overflow, circular file references, token mines, alignment triggers). 

## Considerations

Deploying defences is never free. Key tradeoffs include:

- **Token costs and latency**: LLM-based detection, sanitization, and dual-execution approaches all add one or more extra model calls per request. Lightweight classifier-based detection (DeBERTa family) is typically very fast; full LLM-judge evaluation can add many seconds.
- **Utility degradation**: every defence risks false positives, blocking legitimate requests. 
- **Combination of many approaches**: in practice, many deployed systems layer multiple techniques. Layering improves coverage but also compounds costs.
- **Data sharing**: some solutions might involve sharing prompts with third-party infrastructure.

Evaluation is also genuinely difficult:
- The landscape changes rapidly. Not to mention multimodal injections.
- Solutions that rely on a DB of known attacks are only as good as that DB — and the DB is always incomplete and shifting.
- Benchmarks vary widely in methodology, and published numbers are often not directly comparable across papers.

If possible, stick to the [Rule of Two](https://ai.meta.com/blog/practical-ai-agent-security/).
If you are deploying or using a high-privilege system that is intrinsically subject to prompt injections, be careful and good luck.
