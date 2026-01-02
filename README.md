# CoLogger

**AI-Powered Log Analysis for IT Service Desk**

CoLogger uses local Large Language Models to automatically analyze system logs and generate actionable insights. No cloud dependencies required.

## Features

- Local LLM integration (Ollama, LM Studio, OpenAI-compatible APIs)
- Multi-file log analysis
- Customizable prompt templates (security, performance, error tracking)
- Professional markdown reports
- Portable Windows executable

## Prerequisites

- Windows 10/11 or Windows Server
- PowerShell 5.1+ (included in Windows)
- Local LLM service: [Ollama](https://ollama.ai/), [LM Studio](https://lmstudio.ai/), or OpenAI-compatible API

## Installation

1. Download `cologger.exe` from [Releases](../../releases)
2. Double-click to run (no installation needed)
3. CoLogger creates required folders and configuration automatically

## Quick Start

### 1. Launch CoLogger
Run `cologger.exe` to see the main menu with three options: Test LLM Connection, Analyze Logs, or Exit.

### 2. Configure LLM Connection
Edit the auto-generated `config.json` file:

```json
{
  "apiEndpoint": "http://localhost",
  "apiPort": 11434,
  "apiPath": "/v1/chat/completions",
  "model": "qwen2.5:latest",
  "temperature": 0.3,
  "maxTokens": 4096,
  "timeoutSeconds": 30
}
```

For LM Studio, change `apiPort` to `1234`.

### 3. Add Log Files
Place `.log` files in the `logs/` folder.

### 4. Test Connection
Select menu option `1` to verify LLM connectivity.

### 5. Analyze Logs
Select menu option `2`, choose a prompt template (or use default), and wait for analysis. Reports are saved in the `reports/` folder.

## Prompt Templates

CoLogger includes three built-in templates:
- **Security Focus**: Authentication failures, vulnerabilities, unauthorized access
- **Performance Analysis**: Bottlenecks, resource issues, optimization
- **Error Tracking**: Errors, exceptions, failure patterns

Create custom templates by adding `.txt` files to the `prompts/` folder.

## Configuration

Key `config.json` parameters:
- `apiEndpoint`: LLM service hostname
- `apiPort`: Service port (11434 for Ollama, 1234 for LM Studio)
- `model`: Model name (qwen2.5:latest, llama3.2, mistral, etc.)
- `temperature`: Response creativity (0.0-1.0)
- `maxTokens`: Maximum response length
- `timeoutSeconds`: Request timeout

## Troubleshooting

**LLM Connection Failed**
- Ensure LLM service is running (e.g., `ollama serve`)
- Verify `config.json` has correct endpoint and port
- Check firewall settings

**No Log Files Found**
- Confirm `.log` files exist in `logs/` folder
- Verify file extensions are `.log`

**Request Timeout**
- Increase `timeoutSeconds` in `config.json`
- Split large log files into smaller chunks

## License

MIT License - Copyright (c) 2026 Third Eye Consulting

---

**CoLogger** - Intelligent log analysis, locally powered.
