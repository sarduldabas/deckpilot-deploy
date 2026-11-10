"""Checks your Microsoft Foundry deployment before you run DeckPilot in Azure mode.

  1. plain model call
  2. web_search tool call (the one research-service relies on)

Reads AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_API_KEY, AZURE_OPENAI_DEPLOYMENT from the environment.
Optional: LLM_REASONING_EFFORT (e.g. low). Never prints the key.
Setup:  pip install openai
"""
import os
import sys
import time

from openai import OpenAI

missing = [v for v in ("AZURE_OPENAI_ENDPOINT", "AZURE_OPENAI_API_KEY", "AZURE_OPENAI_DEPLOYMENT") if not os.getenv(v)]
if missing:
    sys.exit("Missing environment variable(s): " + ", ".join(missing))

client = OpenAI(base_url=os.environ["AZURE_OPENAI_ENDPOINT"], api_key=os.environ["AZURE_OPENAI_API_KEY"], timeout=120)
model = os.environ["AZURE_OPENAI_DEPLOYMENT"]
extra = {"reasoning": {"effort": os.environ["LLM_REASONING_EFFORT"]}} if os.getenv("LLM_REASONING_EFFORT") else {}

print(f"endpoint  : {os.environ['AZURE_OPENAI_ENDPOINT']}")
print(f"deployment: {model}\n")

# 1) plain call
try:
    t0 = time.time()
    r = client.responses.create(model=model, input="Reply with exactly five words.", **extra)
    print(f"[1] LLM call OK ({time.time() - t0:.1f}s): {r.output_text!r}")
except Exception as exc:  # noqa: BLE001
    print(f"[1] LLM call FAILED: {type(exc).__name__}: {exc}")
    sys.exit(1)

# 2) web search tool
try:
    t0 = time.time()
    r = client.responses.create(
        model=model,
        tools=[{"type": "web_search"}],
        input="In two sentences: what is the latest news on solar power in India? Cite sources.",
        include=["web_search_call.action.sources"],
        **extra,
    )
    kinds = [getattr(o, "type", "?") for o in r.output]
    cites = []
    for item in r.output:
        if getattr(item, "type", "") == "message":
            for part in getattr(item, "content", None) or []:
                cites += [a.url for a in (getattr(part, "annotations", None) or []) if getattr(a, "type", "") == "url_citation"]
    print(f"[2] web_search call OK ({time.time() - t0:.1f}s)")
    print(f"    output item types : {kinds}")
    print(f"    searched          : {'web_search_call' in kinds}")
    print(f"    citations         : {len(cites)}")
    print(f"    answer            : {r.output_text[:400]!r}")
    print("\nRESULT:", "ALL GOOD" if "web_search_call" in kinds and cites else "web search ran but returned no citations - tell Claude")
except Exception as exc:  # noqa: BLE001
    print(f"[2] web_search call FAILED: {type(exc).__name__}: {exc}")
    sys.exit(2)
