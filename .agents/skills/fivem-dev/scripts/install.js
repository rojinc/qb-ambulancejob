#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');

const PLUGIN_NAME = 'fivem-dev';

// Copy directory recursively
function copyDir(src, dest) {
  if (!fs.existsSync(dest)) {
    fs.mkdirSync(dest, { recursive: true });
  }

  const entries = fs.readdirSync(src, { withFileTypes: true });

  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);

    if (entry.name === 'node_modules' || entry.name === '.git') {
      continue;
    }

    if (entry.isDirectory()) {
      copyDir(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

function install() {
  const packageDir = path.resolve(__dirname, '..');
  const homeDir = os.homedir();

  // Install to BOTH locations for compatibility
  const skillsDir = path.join(homeDir, '.claude', 'skills', PLUGIN_NAME);
  const pluginsDir = path.join(homeDir, '.claude', 'plugins', 'marketplaces', PLUGIN_NAME);

  console.log(`\n🎮 Installing FiveM Dev Plugin for Claude Code...\n`);
  console.log(`   Source: ${packageDir}`);
  console.log(`   Skills: ${skillsDir}`);
  console.log(`   Plugins: ${pluginsDir}\n`);

  try {
    // Install to skills directory (for /skill fivem-dev)
    if (!fs.existsSync(skillsDir)) {
      fs.mkdirSync(skillsDir, { recursive: true });
    }
    copyDir(packageDir, skillsDir);
    console.log(`✅ Installed to skills directory`);

    // Install to plugins directory (for /fivem-dev command)
    if (!fs.existsSync(pluginsDir)) {
      fs.mkdirSync(pluginsDir, { recursive: true });
    }
    copyDir(packageDir, pluginsDir);
    console.log(`✅ Installed to plugins directory`);

    console.log(`\n🎉 FiveM Dev Plugin installed successfully!\n`);
    console.log(`📚 Usage:`);
    console.log(`   - Ask FiveM questions naturally (skill auto-activates)`);
    console.log(`   - Use /fivem-dev <query> for direct questions`);
    console.log(`   - Restart Claude Code after installation\n`);
    console.log(`🔗 Docs: https://github.com/melihbozkurt10/fivem-dev-plugin\n`);

  } catch (error) {
    console.error(`❌ Installation failed: ${error.message}`);
    console.error(`\nManual installation:`);
    console.error(`   Copy contents to: ${skillsDir}`);
    process.exit(1);
  }
}

install();
