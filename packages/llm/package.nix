{
  lib,
  python3Packages,
}:

python3Packages.llm.overrideAttrs (oldAttrs: {
  meta = oldAttrs.meta // {
    description = "CLI tool and Python library for interacting with Large Language Models";
    longDescription = ''
      LLM is a CLI utility and Python library for interacting with OpenAI,
      Anthropic's Claude, Google's Gemini, Meta's Llama and dozens of other
      Large Language Models. It supports executing prompts from the terminal,
      storing interactions in SQLite databases, generating embeddings, and
      extracting structured data from text and images.
    '';
    homepage = "https://llm.datasette.io/";
    changelog = "https://github.com/simonw/llm/releases";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.all;
    mainProgram = "llm";
  };
})
