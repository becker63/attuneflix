use zed_extension_api::{self as zed, Command, LanguageServerId, Result, Worktree};

struct FlixExtension;

impl zed::Extension for FlixExtension {
    fn new() -> Self {
        Self
    }

    fn language_server_command(
        &mut self,
        _language_server_id: &LanguageServerId,
        worktree: &Worktree,
    ) -> Result<Command> {
        let project_launcher = format!("{}/zed/flix-lsp", worktree.root_path());
        if worktree.read_text_file("zed/flix-lsp").is_ok() {
            return Ok(Command {
                command: project_launcher,
                args: Vec::new(),
                env: Default::default(),
            });
        }

        let command = worktree.which("flix").ok_or_else(|| {
            "Flix was not found in PATH. Install it or enter the AttuneFlix Nix environment."
                .to_string()
        })?;

        Ok(Command {
            command,
            args: vec!["lsp".to_string()],
            env: Default::default(),
        })
    }
}

zed::register_extension!(FlixExtension);
