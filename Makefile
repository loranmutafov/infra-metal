.PHONY: deploy deployon deploy-nina deploy-eli deploy-100yan

deploy:
	./ops/scripts/deploy.sh

deployon:
	./ops/scripts/deploy.sh "--on $(filter-out $@,$(MAKECMDGOALS))"

deploy-nina:
	./ops/scripts/deploy.sh "--on metal-nina"

deploy-eli:
	./ops/scripts/deploy.sh "--on metal-eli"

deploy-100yan:
	./ops/scripts/deploy.sh "--on metal-100yan"
