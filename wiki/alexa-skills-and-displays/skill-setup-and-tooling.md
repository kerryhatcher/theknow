---
description: Accounts, skill architecture, tooling, and deployment options for building Alexa custom skills.
---

# Setup and tooling

Before you write code, understand the account model and deployment landscape. This page covers what a skill actually is, why you need two separate accounts, the ASK CLI, the Developer Console, and why hosting choices constrain what language you write in.

## Accounts and artifacts

An **Alexa skill** is not a single object. It is a packet of three things:

1. **Interaction model**, a JSON file that defines what users can say (intents, slots, sample utterances) and invocation name.
2. **Manifest** (skill.json), metadata that names the skill, sets the endpoint, declares the stage (development vs. live), and registers the skill ID in Alexa's system.
3. **Endpoint**, the backend that receives requests and returns responses (speech, cards, APL directives).

These three pieces together form a "Custom Alexa Skill," the general-purpose skill type. You do not need these things for Smart Home skills (which use a fixed schema to control devices) or Flash Briefing skills (which deliver content updates), so rule those out first: if you want a screen dashboard with arbitrary voice commands, you need **Custom**.

### Two accounts, separate purposes

You will need **both** an Amazon developer account and an AWS account. They are not the same.

| Account | What it is | Why you need it | Cost |
|---------|-----------|-----------------|------|
| **Amazon Developer** | Your identity in Amazon's developer ecosystem. Created at https://developer.amazon.com. | Required to create and test skills in the Developer Console, interact with the Skill Management API, and access ASK CLI. | Free. |
| **AWS Account** | Your identity in Amazon Web Services (EC2, Lambda, S3, DynamoDB, etc.). Created at https://aws.amazon.com. | Required if you host your backend on AWS Lambda or use other AWS services (DynamoDB for sessions, S3 for assets). **Not required if you use Alexa-hosted skills or a self-managed HTTPS server elsewhere.** | Free tier: 1M Lambda requests/month, 400,000 GB-seconds/month. After free tier, ~$0.20 per 1M requests + compute time. See [AWS Lambda pricing](https://aws.amazon.com/lambda/pricing/). |

The Developer account runs the console and skill metadata. The AWS account runs your code. You link them via `ask configure` (the CLI stores your credentials for both).

## Skill stages and who can use them

A skill has two deployment stages, and the boundary between them matters.

| Stage | Audience | Certification required | Store listing | When to use |
|-------|----------|------------------------|----------------|------------|
| **Development** | Any device signed into the **same Amazon developer account** that created the skill. Also any testers you explicitly invite via beta testing (can be different accounts). | No | No | Your own devices, family testing, prototyping. In development, a skill runs on *every* device registered to that account. This is the path for personal dashboards. |
| **Live** (Published) | Anyone, discoverable in the Alexa Skills Store. | Yes, 5+ business days of Amazon review. | Yes | Public distribution. Required if you want strangers to find your skill. |

Critical implication: if you leave a skill in development stage, it is **not** a secret — it is enabled on every Alexa device signed into your developer account. If you have an Echo Dot, an Echo Show, and a Fire tablet, all three will see the development skill in their app. This is by design and is the entire reason development stage exists: no need to loop back through certification for personal use.

{% hint style="warning" %}
**The 8-second wall:** Alexa expects a full response (speech + display + all API calls) in roughly 8 seconds. By the time the user finishes speaking and Alexa's ASR runs, you have maybe 6-7 seconds left. This is hardware-level and you cannot negotiate it. See [ai-agent-orchestration](../backend-rust.md) before committing to an LLM-heavy design; most Alexa + AI projects fail here.
{% endhint %}

## The Alexa Developer Console

All skill configuration, testing, and submission happens at https://developer.amazon.com/alexa/console/ask.

| Section | What you do |
|---------|------------|
| **Build** | Edit interaction model (intents, slots, sample utterances) in a visual editor or JSON. Build the model to compile and validate it. |
| **Code** | Edit your endpoint code directly (Alexa-hosted only) or register the Lambda ARN / HTTPS URL (self-hosted). |
| **Build > APL Editor** | Visually author screen layouts. Drag components, set colors, bind data, preview on Echo Show sizes. Export as APL JSON document to include in your skill code. See [apl-displays.md](apl-displays.md). |
| **Test** | Simulator for text/voice utterances, preview APL on virtual screen sizes, inspect full request/response JSON payloads. Cannot test real touch input or some device-specific features (AudioPlayer, real Webcam). Requires a real Echo Show for pixel-accurate layout and touch. |
| **Distribution** | Name, category, description, icon. Pre-submit validation checks. |
| **Certification** | Submit for review, check status, see feedback if rejected. |

Start here to understand the skill's configuration shape, but the console is read-only if you version-control your code (recommended). The interaction model and APL documents are JSON; you commit them to Git alongside your backend code and deploy via the ASK CLI.

## ASK CLI: the command line interface

The Alexa Skills Kit CLI (`ask-cli`) is the primary way to create, build, and deploy skills locally. **Version 2.x is current** (v2 is the active branch; v1 projects must upgrade before deploying).

Install:
```bash
npm install -g ask-cli
ask configure
```

`ask configure` opens a browser to authenticate your Amazon developer account and links your AWS profile, storing both credentials locally.

### Core commands

```bash
ask new                    # Create a new skill from a template.
ask deploy                 # Build and deploy to your target (Lambda, Alexa-hosted, or HTTPS).
ask dialog                 # Send test utterances to your skill endpoint without the console.
ask smapi get-skill        # Query skill metadata via the Skill Management API (advanced).
```

Example workflow:
```bash
ask new --skill-name my-dashboard --runtime python --template hello-world
cd my-dashboard
# Edit lambda/lambda_handler.py and models/en-US.json
ask deploy
# Skill is now live in development stage; test on your device or in the console simulator.
```

`ask new` prompts for runtime (Node.js, Python, Java), skill type (Custom), and hosting (Alexa-hosted vs. self-hosted Lambda). Your language choice here is binding if you pick Alexa-hosted; you cannot change it later.

## Hosting: trade-offs

Three paths, each with constraints.

| Hosting | Runtimes | Cost | Setup | When to use |
|---------|----------|------|-------|------------|
| **Alexa-hosted** | Node.js 16.x, Python 3.8 | Free tier: 1M Lambda requests + 1GB DynamoDB storage + 3GB S3 per month | Minutes. Click "Create Skill," pick Node or Python, edit in the console or locally. `ask deploy` uploads to Amazon's AWS account. | Prototyping, personal skills, or any skill where Node/Python suffices and you want zero infrastructure management. **Cannot use Rust.** |
| **AWS Lambda** (your account) | Node.js, Python, Java, Rust (via provided.al2023), others via custom runtime | Free tier: 1M requests, 400,000 GB-seconds/month. $0.20 per 1M requests + memory-time charges after free tier. | Hours. Create AWS account, write code locally, deploy with `cargo-lambda` (Rust), SAM, Terraform, or `ask deploy`. Register Lambda ARN in the Developer Console. | Production workloads, anything requiring Rust, when you need custom VPC/security posture, or when you want detailed cost control. |
| **Self-hosted HTTPS** | Any language (your choice) | Your infrastructure costs (EC2, container registry, TLS certs, uptime monitoring). | Days. You implement Alexa's request signature verification, handle HTTPS, scaling, and uptime. | Rare. Only if you have infrastructure elsewhere or need specific compliance/data residency. |

**Rust requires self-hosted Lambda** (AWS Lambda's Rust support is available but requires the `provided.al2023` OS-only runtime, compiled to a native binary). Alexa-hosted does not support Rust.

## Project layout (ASK CLI)

When you `ask new`, you get this structure:

```
my-skill/
  ask-resources.json          # ASK CLI metadata (skill ID, profiles, backend ARN)
  skill.json                  # Skill manifest (invocation name, endpoint, permissions, locales)
  lambda/                     # Backend code directory
    lambda_handler.py         # (or .js for Node)
    requirements.txt          # Python dependencies
    Cargo.toml                # (if self-hosted Rust)
  models/
    en-US.json                # Interaction model (intents, slots, utterances)
  infrastructure/
    ask-resources.yaml        # CloudFormation template (Alexa-hosted only)
```

**What to commit to Git:** `skill.json`, `models/`, `lambda/` code, `Cargo.toml`, `requirements.txt`. **Do not commit:** `.ask/`, AWS credentials, `node_modules/`, compiled binaries.

**For a Rust backend:** follow [cargo-lambda](https://www.cargo-lambda.info/) conventions. The `ask new` templates do not include Rust, so scaffold it yourself:

```bash
cargo lambda new my-skill --http
# Deploy with: cargo lambda deploy my-skill
```

Then register the resulting Lambda ARN in the Developer Console's **Build > Endpoint** tab.

## Costs and free tier

Spelled out so you can verify against the source.

**Lambda:** Free tier of 1,000,000 requests per month + 400,000 GB-seconds per month (per AWS region, per account). After free tier:

- **$0.20 per 1 million requests**
- **$0.0000166667 per GB-second** (memory-seconds; 128 MB = 0.125 GB)

Example: a 256 MB function taking 500 ms costs roughly `(0.256 GB × 0.5 s) × $0.0000166667 = $0.000002133 per invocation`. At 10K daily invocations, ~$0.64/month.

**Alexa-hosted:** The free tier remains free indefinitely (1M requests, 1GB DynamoDB, 3GB S3). If you exceed it, you get billed at AWS's standard rates for the overage, but the first tier is perpetually free.

**Developer Console:** Free. No fees for using the simulator, console, or certification submission.

See [AWS Lambda pricing](https://aws.amazon.com/lambda/pricing/) for current rates and [Alexa Developer pricing](https://developer.amazon.com/en-US/alexa/alexa-skills-kit/aws-cloud-services) for Alexa-hosted free tier limits.

## Next steps

- [interaction-model.md](interaction-model.md) — Define intents, slots, and sample utterances.
- [apl-displays.md](apl-displays.md) — Build screen layouts for Echo Show.
- [backend-rust.md](backend-rust.md) — Write the fulfillment endpoint (Lambda + Rust, or Node/Python).
- [testing-and-publishing.md](testing-and-publishing.md) — Testing on device, beta testing, and certification submission.

## Sources

- [ASK CLI Overview](https://developer.amazon.com/en-US/docs/alexa/smapi/ask-cli-intro.html), Alexa Skills Kit official documentation
- [About Alexa-Hosted Skills](https://developer.amazon.com/en-US/docs/alexa/hosted-skills/build-a-skill-end-to-end-using-an-alexa-hosted-skill.html), Alexa Skills Kit official documentation
- [Lambda runtimes](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html), AWS Lambda documentation
- [Building Lambda functions with Rust](https://docs.aws.amazon.com/lambda/latest/dg/lambda-rust.html), AWS Lambda documentation
- [AWS Lambda Pricing](https://aws.amazon.com/lambda/pricing/), AWS
- [Alexa Developer Account and AWS Account Setup](https://developer.amazon.com/en-US/docs/alexa/custom-skills/host-a-custom-skill-as-an-aws-lambda-function.html), Alexa Skills Kit official documentation
- [Test and Submit Your Skill](https://developer.amazon.com/en-US/docs/alexa/devconsole/test-and-submit-your-skill.html), Alexa Skills Kit official documentation
- [What's New in APL 2024.3](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/apl-latest-version.html), Alexa Skills Kit official documentation
- [AWS Lambda now supports Rust](https://aws.amazon.com/blogs/compute/aws-lambda-now-supports-rust/), AWS Compute Blog
