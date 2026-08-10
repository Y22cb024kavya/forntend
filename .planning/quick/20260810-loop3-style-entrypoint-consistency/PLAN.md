# Loop 3: Style Entry-Point Consistency

## Objective

Prove whether the Home prompt bar and Style Me CTA use different Style
execution paths for colour-advice prompts, then make the smallest safe fix if
the current source shows a real divergence.

## Constraints

- Do not create numbered GSD phase metadata.
- Do not change Visual Inspiration, Style This, Build Outfit, board ranking,
  backend reasoning, deployment, or production traffic.
- Do not touch generated Flutter files or unrelated dirty files.

## Verification

- Trace both entry points before implementation.
- Compare endpoint, module/domain, history, context, response parsing, and
  renderer behavior.
- Add focused parity and continuity coverage only after the divergence is
  proven.
