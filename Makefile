.PHONY: deploy deployon deploy-nina deploy-eli deploy-100yan deploy-ionos-ber-1

deploy:
	./ops/scripts/deploy.sh

deployon:
	./ops/scripts/deploy.sh "--on $(filter-out $@,$(MAKECMDGOALS))"

deploy-nina:
	./ops/scripts/deploy.sh "--on metal-nina $(filter-out $@,$(MAKECMDGOALS))"

deploy-eli:
	./ops/scripts/deploy.sh "--on metal-eli $(filter-out $@,$(MAKECMDGOALS))"

deploy-100yan:
	./ops/scripts/deploy.sh "--on metal-100yan $(filter-out $@,$(MAKECMDGOALS))"

deploy-ionos-ber-1:
	./ops/scripts/deploy.sh "--on vps-ionos-ber-1 $(filter-out $@,$(MAKECMDGOALS))"

update:
	./ops/scripts/nixcmd.sh nix flake update
