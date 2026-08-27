/*
 * Static rules for Omarchy shell plugins.
 *
 * Threat model: a plugin is unsandboxed QML loaded into the long-lived
 * omarchy-shell process, plus whatever scripts it ships and runs. It has the
 * user's full authority, at login, forever. There is no runtime sandbox --
 * PluginRegistry.qml only contains entry-point *paths*, not execution.
 *
 * These rules are tuned for that surface (.qml/.sh/.js/.rb/.jq), not for
 * PE/ELF malware. Severity is deliberately conservative about the things every
 * legitimate plugin does: running a command is normal here, so `Process` alone
 * is informational. What earns a high severity is code that fetches and
 * executes, hides what it is doing, reaches for credentials, or arranges to
 * keep running outside the plugin lifecycle.
 *
 * Every rule carries `why` so the report can explain itself, and so the LLM
 * pass has the reviewer's intent rather than just a rule name.
 */

private rule TextSource {
  strings:
    $qml = "import Qt"
    $sh1 = "#!/bin/bash"
    $sh2 = "#!/bin/sh"
    $sh3 = "#!/usr/bin/env"
    $js  = "function "
    $rb  = "require "
  condition:
    any of them or filesize < 2MB
}

/* ---------------------------------------------------------------- callbacks */

rule callback_fetch_pipe_shell {
  meta:
    severity = "high"
    category = "callback"
    why = "Downloads code and executes it in one step, so what runs is whatever the server returns at that moment. Nothing reviewable is pinned."
  strings:
    $a = /curl[^\n|]{0,200}\|[ \t]*(ba)?sh[ \t]*(\n|$|;|\||&)/
    $b = /wget[^\n|]{0,200}\|[ \t]*(ba)?sh[ \t]*(\n|$|;|\||&)/
    $c = /curl[^\n]{0,200}--output[^\n]{0,120}&&[^\n]{0,60}(chmod|\.\/)/
    $d = /fetch\([^\n]{0,200}\)[^\n]{0,80}eval/
  condition:
    any of them
}

rule callback_outbound_http {
  meta:
    severity = "medium"
    category = "callback"
    why = "Contacts a host over the network. Legitimate for weather, update checks and marketplace metadata; the question is which host, and whether anything local is sent with it."
  strings:
    $curl  = /\bcurl\b[^\n]{0,200}https?:\/\//
    $wget  = /\bwget\b[^\n]{0,200}https?:\/\//
    $xhr   = "XMLHttpRequest"
    $fetch = /\bfetch\s*\(\s*["'`]https?:/
  condition:
    any of them
}

rule capability_opens_browser {
  meta:
    severity = "info"
    category = "capability"
    why = "Hands a URL to the user's browser. Visible to the user and not silent egress, so it is recorded as reach rather than as a callback -- but check what the URL is built from."
  strings:
    $a = "Qt.openUrlExternally"
    $b = /omarchy[ \t]+launch[ \t]+browser/
  condition:
    any of them
}

rule callback_raw_ip_address {
  meta:
    severity = "high"
    category = "callback"
    why = "Talks to a bare IP rather than a hostname. Plugins that use a real service use its domain; a hard-coded address avoids DNS logging and certificate names."
  strings:
    $ip = /https?:\/\/([0-9]{1,3}\.){3}[0-9]{1,3}/
  condition:
    $ip
}

rule callback_dns_exfiltration {
  meta:
    severity = "high"
    category = "callback"
    why = "Builds a DNS lookup out of local data. A resolver request smuggles the data out even where outbound HTTP is blocked."
  strings:
    $a = /(\A|[\n;&|`]|\$\()[ \t]*(dig|nslookup)[ \t]+[^\n]{0,120}\$[({]/
    $b = /(\A|[\n;&|`]|\$\()[ \t]*(dig|nslookup)[ \t]+[^\n]{0,120}(TXT|txt)/
    $c = /(\A|[\n;&|`]|\$\()[ \t]*host[ \t]+[^\n=]{0,40}\$[({]/
  condition:
    any of them
}

rule callback_raw_socket {
  meta:
    severity = "high"
    category = "callback"
    why = "Opens a socket directly instead of using an HTTP client. This is the usual shape of a reverse shell or a hand-rolled exfil channel."
  strings:
    $devtcp = "/dev/tcp/"
    $devudp = "/dev/udp/"
    $nc     = /\bnc\b[ \t]+(-[a-zA-Z]+[ \t]+){0,3}[0-9a-zA-Z.\-]+[ \t]+[0-9]{2,5}/
    $ncat   = /\bncat\b[^\n]{0,80}-e\b/
    $socat  = /\bsocat\b[^\n]{0,120}EXEC:/
  condition:
    any of them
}

/* -------------------------------------------------------------- obfuscation */

rule obfuscation_encoded_execution {
  meta:
    severity = "high"
    category = "obfuscation"
    why = "Decodes a blob and runs it. There is no legitimate reason for a plugin's own logic to be unreadable in its own repository."
  strings:
    $b64sh  = /base64[ \t]+(-d|--decode)[^\n|]{0,80}\|[ \t]*(ba)?sh[ \t]*(\n|$|;|\||&)/
    $b64ev  = /eval[^\n]{0,80}base64[ \t]+(-d|--decode)/
    $gz     = /(gunzip|zcat|gzip[ \t]+-d)[^\n|]{0,80}\|[ \t]*(ba)?sh[ \t]*(\n|$|;|\||&)/
    $xxd    = /xxd[ \t]+-r[^\n|]{0,80}\|[ \t]*(ba)?sh[ \t]*(\n|$|;|\||&)/
    $atob   = /eval\s*\(\s*atob\s*\(/
  condition:
    any of them
}

rule obfuscation_dynamic_code {
  meta:
    severity = "medium"
    category = "obfuscation"
    why = "Builds code at runtime, so the behaviour is not visible in the source. In QML this also escapes any review of the declared entry points."
  strings:
    $qml   = "Qt.createQmlObject"
    $fn    = /new\s+Function\s*\(/
    $eval  = /\beval\s*\(/
  condition:
    any of them
}

rule capability_shell_indirection {
  meta:
    severity = "info"
    category = "capability"
    why = "Runs a command through `sh -c` with an interpolated value. Extremely common and usually fine, but it is the seam where an unquoted variable becomes command injection, so it is worth knowing which values reach it."
  strings:
    $shc = /(ba)?sh[ \t]+-c[ \t]+["']?\$/
  condition:
    $shc
}

rule obfuscation_escaped_string_run {
  meta:
    severity = "medium"
    category = "obfuscation"
    why = "A long run of hex or octal escapes is a way to keep a string out of grep. Normal source does not need it."
  strings:
    $hex = /(\\x[0-9a-fA-F]{2}){8,}/
    $oct = /(\\[0-7]{3}){8,}/
    $chr = /(String\.fromCharCode|fromCharCode)\s*\([0-9, ]{20,}/
  condition:
    any of them
}

rule obfuscation_reversed_command {
  meta:
    severity = "medium"
    category = "obfuscation"
    why = "Reversing or character-shuffling a command string hides it from a reader and from simple scanning."
  strings:
    $rev = /\|[ \t]*rev[ \t]*\|[ \t]*(ba)?sh[ \t]*(\n|$|;|\||&)/
    $tr  = /\btr\b[^\n|]{0,60}\|[ \t]*(ba)?sh[ \t]*(\n|$|;|\||&)/
  condition:
    any of them
}

/* --------------------------------------------------------------- credential */

rule credential_secret_paths {
  meta:
    severity = "high"
    category = "credential"
    why = "Reads private keys, cloud credentials or password stores. A shell plugin has no reason to touch these."
  strings:
    $ssh   = /\.ssh\/(id_[a-z0-9]+|authorized_keys|config)/
    $aws   = /\.aws\/(credentials|config)/
    $gpg   = ".gnupg/"
    $netrc = ".netrc"
    $kube  = ".kube/config"
    $pass  = /\.password-store\//
    $env   = /(cat|cp|read|source)[ \t]+[^\n]{0,60}\.env\b/
  condition:
    any of them
}

rule credential_steals_other_program_secrets {
  meta:
    severity = "high"
    category = "credential"
    why = "Reads credentials belonging to another program. Unlike a plugin using its own API key, there is no version of this that is part of a plugin's job."
  strings:
    $a = ".claude/.credentials"
    $b = /\.config\/(gh|gcloud)\/[a-z_]*\.(json|yml|yaml)/
    $c = /\bgh\b[ \t]+auth[ \t]+token/
    $d = /\bpass[ \t]+show\b/
  condition:
    any of them
}

rule capability_reads_own_api_key {
  meta:
    severity = "info"
    category = "capability"
    why = "Reads an API key for the service this plugin integrates with. Expected for anything talking to a paid or authenticated API -- check the key only travels to that service."
  strings:
    $a = /\b[A-Z][A-Z0-9]{1,15}_(API_KEY|APIKEY|TOKEN)\b/
    $b = "secret-tool lookup"
  condition:
    any of them
}

rule credential_browser_profile {
  meta:
    severity = "high"
    category = "credential"
    why = "Reads a browser profile, which holds cookies, sessions and saved passwords."
  strings:
    $a = /\.mozilla\/firefox\//
    $b = /\.config\/(google-chrome|chromium|BraveSoftware)\//
    $c = "Login Data"
    $d = "cookies.sqlite"
  condition:
    any of them
}

/* -------------------------------------------------------------- persistence */

rule persistence_hidden_autostart {
  meta:
    severity = "high"
    category = "persistence"
    why = "Hooks a startup path the user does not associate with the plugin. Removing the plugin will not stop it, and nothing in the plugin manager will show it."
  strings:
    $cron      = /\bcrontab\b[ \t]+-/
    $autostart = /\.config\/autostart\//
    $bashrc    = /(>>|tee[ \t]+-a)[ \t]*[^\n]{0,40}\.(bashrc|zshrc|profile|bash_profile)/
    $githook   = /\.git\/hooks\//
  condition:
    any of them
}

rule persistence_systemd_unit {
  meta:
    severity = "medium"
    category = "persistence"
    why = "Installs or enables a systemd unit. Normal for a plugin with a background daemon, but the unit keeps running after the plugin is removed unless its uninstall path disables it -- check that it has one."
  strings:
    $systemd  = /systemctl[ \t]+(--user[ \t]+)?enable\b/
    $unitpath = /\.config\/systemd\/user\//
  condition:
    any of them
}

rule privilege_tampering {
  meta:
    severity = "high"
    category = "privilege"
    why = "Edits the rules that govern escalation itself, or makes a binary setuid. This grants standing root rather than asking for it once, and outlives the plugin."
  strings:
    $sudoers  = "/etc/sudoers"
    $nopasswd = "NOPASSWD"
    $suid     = /chmod[ \t]+[0-9]*[46][0-7]{3}/
    $suid2    = /chmod[ \t]+[ugo]*\+s\b/
  condition:
    any of them
}

rule capability_privilege_escalation {
  meta:
    severity = "medium"
    category = "privilege"
    why = "Asks for root for a specific command. pkexec is the sanctioned path for a GUI process on Omarchy and installing a dependency is normal, so this is reported to show what the plugin escalates for -- read the command, not the fact."
  strings:
    $sudo   = /\bsudo\b[ \t]+[^\n]{0,80}/
    $pkexec = /\bpkexec\b/
  condition:
    any of them
}

rule persistence_writes_outside_plugin {
  meta:
    severity = "medium"
    category = "persistence"
    why = "Writes somewhere other than its own plugin and config directories. Worth confirming the target is something the plugin legitimately owns."
  strings:
    $a = /(>|tee)[ \t]*[^\n]{0,20}\/usr\/(share|bin|lib)\//
    $b = /(>|tee)[ \t]*[^\n]{0,20}\/etc\//
    $c = /rm[ \t]+-rf[ \t]+[^\n]{0,20}\$(HOME|\{HOME\})[ \t\n]/
    $d = /\bln[ \t]+-s[^\n]{0,80}\.config\/omarchy\//
  condition:
    any of them
}

/* ------------------------------------------------------------- capabilities */

rule capability_runs_commands {
  meta:
    severity = "info"
    category = "capability"
    why = "Runs external commands. Normal and expected for an Omarchy plugin -- recorded so the report shows the plugin's reach, not because it is suspicious."
  strings:
    $a = "Quickshell.execDetached"
    $b = "Process {"
    $c = "IpcHandler"
  condition:
    any of them
}

rule capability_reads_user_files {
  meta:
    severity = "info"
    category = "capability"
    why = "Reads or writes files through Quickshell. Normal for anything with settings; recorded so the report shows the plugin's reach."
  strings:
    $a = "FileView {"
    $b = "watchChanges"
  condition:
    any of them
}
