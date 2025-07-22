const { execSync } = require('child_process');

// arguments options:
//   1. build=[<JOPLIN_VERSION>|latest/dynamic]
//   2. publish=[<JOPLIN_VERSION>|latest/dynamic]
//
// tag format:
//   - <JOPLIN_VERSION> for specific version
//   - latest for dynamic auto-installation version
//

const repo = 'rickonono3/joplin-terminal-data-api';

const args = process.argv.slice(2);
const buildTag = args.find(arg => arg.startsWith('build='));
const publishTag = args.find(arg => arg.startsWith('publish='));

let build = buildTag ? buildTag.split('=')[1] : null;
let publish = publishTag ? publishTag.split('=')[1] : null;

if (build) {
    if (build === 'latest') build = 'dynamic';
    const buildCommand = `docker build -t ${repo}:${build} . --build-arg JOPLIN_VERSION=${build} ${build === 'dynamic' ? `&& docker tag ${repo}:dynamic ${repo}:latest` : ''}`;
    execSync(buildCommand, { stdio: 'inherit' });
} else if (publish) {
    const publishCommand = `docker login; docker push ${repo}:${publish === 'dynamic' ? 'latest' : publish}`;
    execSync(publishCommand, { stdio: 'inherit' });
} else {
    console.error('No valid build or publish tag provided. Exiting.\nUsage: `node scaffold.js build=?` OR `node scaffold.js publish=?`');
    process.exit(1);
}