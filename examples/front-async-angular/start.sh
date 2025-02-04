#/bin/zsh
set -e
cd ../../clients/client-js
npm run publish-local
version=$(jq -r '.version' package.json)
echo "\n\nInstalling @bancolombia/chanjs-client@$version from local registry"
cd ../../examples/front-async-angular
npm i --registry http://localhost:4873 "@bancolombia/chanjs-client@$version"
npm start