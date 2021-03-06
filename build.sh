#!/usr/bin/env bash

set -e
shopt -s globstar

# Ensure that the CWD is set to script's location
cd "${0%/*}"
CWD=$(pwd)

## TESTS

test-docs-spell-ci () {

	sed -e "s/cSpell\.//g" .vscode/settings.json > .vscode/cspell.json
	cspell -c .vscode/cspell.json articles/docs/**/*.md

}

test-docs-spell () {

	cd $CWD

	echo "Test cspell..."

	sed -e "s/cSpell\.//g" .vscode/settings.json > .vscode/cspell.json
	docker run -v $(PWD):/code dbogatov/docker-images:cspell-latest /usr/bin/cspell -c /code/.vscode/cspell.json /code/articles/docs/**/*.md
	rm .vscode/cspell.json

	echo "cSpell passed!"

}

## TASKS

### DOCUMENTATION START

install-node-tools () {

	cd $CWD

	echo "Installing node modules... Requires Yarn"

	yarn --ignore-engines > /dev/null
}

clean-doc-folder () {

	echo "Cleaning doc folder..."

	rm -rf documentation/out
}

# Should be run in a MkDocs container
gen-articles-docs () { 

	cd $CWD

	echo "Generating articles based documentation... Requires MkDocs (provides mcdocs and pip extensions)"
	
	rm -rf documentation/out/articles
	mkdir -p documentation/out/articles
	
	cd articles
	mkdocs build > /dev/null
	cd ..
	
	mv articles/site/* documentation/out/articles
}

gen-server-docs () { 

	cd $CWD

	echo "Generating server side code documentation... Requires Doxygen"
	
	rm -rf documentation/out/doxygen
	mkdir -p documentation/out/doxygen
	doxygen Doxyfile > /dev/null
}

gen-client-docs () { 

	cd $CWD

	echo "Generating client side code documentation... Requires TypeDoc (Installed by Yarn or NPM)"
	
	rm -rf documentation/out/typedoc
	mkdir -p documentation/out/typedoc
	
	$(npm bin)/typedoc --logger none client/ts/ > /dev/null
	
	printf "\n"
}

gen-api-docs () {

	cd $CWD

	echo "Generating API documentation... Requires Spectacle (Installed by NPM)"
	
	rm -rf documentation/out/swagger
	mkdir -p documentation/out/swagger
	
	$(npm bin)/spectacle api.yml -t documentation/out/swagger > /dev/null
}

merge-docs () {

	cd $CWD

	echo "Merging documentation..."

	mv documentation/out/doxygen/html/* documentation/out/doxygen
	rm -rf documentation/out/doxygen/html

	mv documentation/out/articles/* documentation/out
	rm -rf documentation/out/articles
}

### DOCUMENTATION END

install-client-libs () {

	cd $CWD/client

	echo "Installing front-end libraries... Requires Yarn"
	yarn --ignore-engines > /dev/null

}

install-typings () {

	cd $CWD

	echo "Installing TypeScript typings... Requires Typings (Installed by Yarn)"
	mkdir -p client/typings
	$(yarn bin)/typings install > /dev/null

}

generate-client-bundle () {

	cd $CWD

	echo "Bundling front-end libraries... Requires Webpack (Installed by Yarn)"
	rm -rf src/web/wwwroot/{js,css}/*

	$(yarn bin)/webpack --context client/ --env prod --config client/webpack.config.js --output-path src/web/wwwroot/js > /dev/null

	mkdir -p src/web/wwwroot/css/
	mv src/web/wwwroot/js/app.min.css src/web/wwwroot/css/
	rm src/web/wwwroot/js/less.*

}

restore-dotnet () {

	cd $CWD/src

	echo "Restoring .NET dependencies... Requires .NET SDK"
	dotnet restore daemons/daemons.csproj > /dev/null
	dotnet restore web/web.csproj > /dev/null
}

build-dotnet () {

	cd $CWD/src

	echo "Building and publishing .NET app... Requires .NET SDK"
	dotnet publish -c release daemons/daemons.csproj > /dev/null
	dotnet publish -c release web/web.csproj > /dev/null
}

move-static-files () {

	cd $CWD

	echo "Moving static files..."

	mkdir -p documentation/out/
	cp deploy.sh documentation/out/
	chmod -x documentation/out/deploy.sh
}

build-compose-files () {

	cd $CWD

	if [ "$DOTNET_TAG" == "master" ]; then
		echo "Not need to build for master"
		return
	fi

	if [ -z "$DOTNET_TAG" ]; then
		DOTNET_TAG="local"
	fi

	echo "Building ${DOTNET_TAG} stack..."

	composition=$(<docker-compose.yml)
	echo "${composition//-master/-$DOTNET_TAG}" > docker-compose.yml
}

build-ping-server () {
	cd $CWD/ping

	echo "Building ping server..."

	env GOOS=linux GOARCH=amd64 go build -o bin/ping main/main.go 
}

build-dev-client () {

	cd $CWD

	echo "Cleaning dist/"
	rm -rf client/dist/

	echo "Copying source files"
	mkdir -p client/dist/{ts,less}
	cp -R client/ts/* client/dist/ts/
	cp -R client/less/* client/dist/less/

	echo "Bundling front-end libraries... Requires Webpack (Installed globally)"
	webpack --env dev --display-error-details --output-path client/dist/ts --config client/webpack.config.js --context client/

	echo "Copying generated code"
	mkdir -p src/web/wwwroot/js/ts
	cp -R client/dist/ts/* src/web/wwwroot/js/ts/
	cp client/dist/ts/app.css src/web/wwwroot/css/app.css

	echo "Removing temporary directory"
	rm -rf client/dist/

	echo "Done!"
}

build-docker-images () {

	cd $CWD

	if [ -z "$DOTNET_TAG" ]; then
		DOTNET_TAG="local"
	fi

	echo "Building web-$DOTNET_TAG"
	docker build -f src/web/Dockerfile -t dbogatov/status-site:web-$DOTNET_TAG src/web/

	echo "Building daemons-$DOTNET_TAG"
	docker build -f src/daemons/Dockerfile -t dbogatov/status-site:daemons-$DOTNET_TAG src/daemons/

	echo "Building docs-$DOTNET_TAG"
	docker build -f documentation/Dockerfile -t dbogatov/status-site:docs-$DOTNET_TAG documentation/

	echo "Building nginx-$DOTNET_TAG"
	docker build -f nginx/Dockerfile -t dbogatov/status-site:nginx-$DOTNET_TAG nginx/

	echo "Building ping-$DOTNET_TAG"
	docker build -f ping/Dockerfile -t dbogatov/status-site:ping-$DOTNET_TAG ping/

	echo "Done!"
}

push-docker-images () {

	if [ -z "$DOTNET_TAG" ]; then
		DOTNET_TAG="local"
	fi

	echo "Pushing web-$DOTNET_TAG"
	docker push dbogatov/status-site:web-$DOTNET_TAG

	echo "Pushing daemons-$DOTNET_TAG"
	docker push dbogatov/status-site:daemons-$DOTNET_TAG

	echo "Pushing docs-$DOTNET_TAG"
	docker push dbogatov/status-site:docs-$DOTNET_TAG

	echo "Pushing nginx-$DOTNET_TAG"
	docker push dbogatov/status-site:nginx-$DOTNET_TAG

	echo "Pushing ping-$DOTNET_TAG"
	docker push dbogatov/status-site:ping-$DOTNET_TAG

	echo "Done!"
}

build-for-compose () {
	build-dotnet
	build-docker-images
}

## Deployment

build-deployment () {

	cd $CWD/deployment

	echo "Building deploy configs..."

	if [ -z "$DOTNET_TAG" ]; then
		DOTNET_TAG="local"
	fi

	./build-services.sh $DOTNET_TAG

	rm -rf config.yaml

	mv services/namespace.yaml config.yaml
	cat services/**/*.yaml >> config.yaml
	cat sources/volume-claim.yaml >> config.yaml
}

## DEBIAN PACKAGE

build-debian-package () {
	
	cd $CWD/debian

	echo "(Re)creating a temporary directory for building..."
	rm -rf build/
	mkdir -p build/status-ctl/

	echo "Copying .jar file, wrapper and scripts..."
	cp status-ctl.sh build/status-ctl/
	cp ../src/appsettings.production.yml build/status-ctl/
	cp ../docker-compose.yml build/status-ctl/
	cp -r Makefile debian/ build/status-ctl

	printf "\n\nDOTNET_TAG=master" >> build/status-ctl/.env

	echo "Building debian package..."
	cd build/status-ctl
	debuild -us -uc
	
	echo "Cleaning tmp files..."
	cd ../..
	rm -rf build/status-ctl

	echo "Done!"
}

## APP BUILDERS

build-app () {

	install-node-tools
	install-client-libs

	install-typings
	generate-client-bundle
	restore-dotnet

	build-dotnet

	echo "Build app completed!"
}

build-docs () {

	install-node-tools
	clean-doc-folder

	gen-articles-docs &
	gen-server-docs &
	gen-client-docs &
	gen-api-docs &

	wait

	merge-docs

	move-static-files

	echo "Build docs completed!"

}

usage () { 
	echo "Usage: $0 [-d -f <string>]" 1>&2 
}

while getopts "f:d" o; do
	case "${o}" in
		f)
			eval $OPTARG
			exit 0
			;;
		d)
			build-dev-client
			exit 0
			;;
		h)
			usage
			exit 0
			;;
		*)
			usage
			exit 1
			;;
	esac
done
shift $((OPTIND-1))

build-app
