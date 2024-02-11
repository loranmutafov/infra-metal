.PHONY: op_inject op_cleanup colmena_apply deploy

GIT_REV=$(git rev-parse --short=8 HEAD)
TMP_DIR=$(mktemp -d -t infra-metal-$GIT_REV.XXXXXXXX)

cleanup:
	rm -rf "${TMP_DIR}"
	echo "Temp directory removed"

bailout:
	echo "🔥 Error, deleting temp directory" 2>&1
	cleanup

op_inject:
	op inject \
		-i machines/gustav/cloudflared-2023.10.0.tpl \
		-o ${TMP_DIR}/cloudflared-2023.10.0

colmena_apply:
	pushd "./machines" && \
		nix-shell -p colmena --run "colmena apply" && \
		popd

deploy:
	trap 'make bailout' ERR
	make op_inject
	make colmena_apply
	make cleanup
	echo "🤘 Metal updated"

old_op_inject:
	op inject \
		-i machines/gustav/cloudflared-2023.10.0.tpl \
		-o machines/gustav/cloudflared-2023.10.0

old_op_cleanup:
	rm machines/gustav/cloudflared-2023.10.0

old_deploy : old_op_inject colmena_apply old_op_cleanup