.PHONY: deploy-script deploy-manual deploy

deploy-script:
	./ops/scripts/deploy.sh

deploy-manual:
	pushd "./machines" && \
		nix-shell -p colmena --run "colmena apply" && \
	popd

deploy: deploy-manual
