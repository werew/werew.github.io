---
title: "Using Hermes’s Quicksort to run Doom: A tale of JavaScript exploitation"
date: 2020-07-20
categories: [Exploitation]
tags: ['JS', 'Hermes']
img_path: "2022-07-20-hermes-doom"
image:
    path: "/banner.webp"
---

**TL;DR**: JavaScript engines are fascinating and challenging from a security perspective due to their exposure to malicious code, memory corruption risks, frequent vulnerabilities, and exploit-friendly nature. I work at Meta on enhancing the security of the widely used Hermes JS engine, which powers React Native and various other applications. I recently published [an article](https://engineering.fb.com/2022/07/20/security/hermes-quicksort-to-run-doom/) about a unique Hermes vulnerability and how it could be exploited to run arbitrary code.

I have always found JavaScript (JS) engines to be some of the most intriguing and enjoyable types of software from a security perspective. Here's why:

- **0-click attack surface**: When we browse the web, we are constantly exposed to potentially malicious JS code running in our browsers. This code leverages the embedded JS engine to process JS assets, making JS engines highly attractive targets for attackers.

- **Susceptibility to memory corruption**: For the sake of performance, most JS engines are written in low-level native languages such as C/C++. Consequently, they are prone to memory corruption-related issues.

- **Bug-prone nature**: Vulnerabilities in JS engines are still quite common, especially due to the complexity and frequent code changes in the ECMAScript standard, which JavaScript is based on.

- **Exploit-friendly environment**: JS Virtual Machines (VM) provide exploit writers with a great deal of flexibility. They can control memory layouts, attempt multiple attacks, and embed a full exploit chain within a single script or payload.

As a result, most major JS engines have adopted various hardening measures to raise the bar for a successful compromise. These measures range from process isolation, such as the Chrome renderer sandboxing, to custom VM heap hardening techniques like those implemented in Webkit or the more recent V8 Ubercage.

In my role at Meta (formerly known as Facebook), I have the opportunity to work on improving the security posture of one of the most widely used JS engines in the industry: [Hermes](https://github.com/facebook/hermes). Hermes is primarily known for powering [React Native](https://reactnative.dev/) applications, but it is also utilized in various other contexts, including scripted [AR effects](https://spark.meta.com/blog/creating-standout-ar-effects-on-instagram/) running on Instagram Reels, Messenger calls, and many other products.

I recently published an engaging walkthrough of a unique Hermes vulnerability discovered by an external security researcher. I discussed how it could have been exploited to execute arbitrary code within Hermes. You can read the full article [here](https://engineering.fb.com/2022/07/20/security/hermes-quicksort-to-run-doom/).
