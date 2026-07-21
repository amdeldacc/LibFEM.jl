"""Generate OpenCode configuration for NVIDIA NIM provider."""
import json
import os

def main():
    config = {
        "$schema": "https://opencode.ai/config.json",
        "provider": {
            "nvidia": {
                "npm": "@ai-sdk/openai-compatible",
                "name": "NVIDIA_NIM",
                "options": {
                    "baseURL": "https://integrate.api.nvidia.com/v1",
                    "apiKey": "{env:NVIDIA_API_KEY}",
                    "reasoningEffort": "high",
                    "textVerbosity": "low"
                },
                "models": {
                    "nvidia/nemotron-3-super-120b-a12b": {"tools": True},
                    "nvidia/nemotron-3-ultra-550b-a55b": {"tools": True},
                    "deepseek-ai/deepseek-v4-flash": {"tools": True},
                    "deepseek-ai/deepseek-v4-pro": {"tools": True},
                    "thinkingmachines/inkling": {"tools": True}
                }
            }
        }
    }

    os.makedirs(os.path.expanduser("~/.config/opencode"), exist_ok=True)
    with open(os.path.expanduser("~/.config/opencode/opencode.json"), "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2)
        f.write("\n")

if __name__ == "__main__":
    main()
