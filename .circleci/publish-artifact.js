#!/usr/bin/env node


const bot = require("circle-github-bot").create();

bot.comment(`
<h3>${bot.env.commitMessage}</h3>
Artifact: <strong>${bot.artifactLink('/artifacts/nextcloud.snap', 'Download')}</strong>
`);