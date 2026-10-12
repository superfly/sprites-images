# Default fish configuration for sprite

# Set terminal title to show current directory
function fish_title
    prompt_pwd
end

# Enable colors
set -g fish_color_normal normal
set -g fish_color_command green
set -g fish_color_param cyan
set -g fish_color_redirection normal
set -g fish_color_comment red
set -g fish_color_error red --bold
set -g fish_color_escape cyan
set -g fish_color_operator cyan
set -g fish_color_quote yellow
set -g fish_color_autosuggestion 555 yellow
set -g fish_color_valid_path --underline
set -g fish_color_cwd green
set -g fish_color_cwd_root red

# Simple prompt
function fish_prompt
    echo -n (whoami)'@'(hostname)':'(prompt_pwd)'$ '
end

# Source language environment variables
if test -r /etc/profile.d/languages_env
    for line in (cat /etc/profile.d/languages_env)
        set -l parts (string replace 'export ' '' $line | string split -m 1 '=')
        if test (count $parts) -eq 2
            set -gx $parts[1] (string trim -c '"' $parts[2])
        end
    end
end
