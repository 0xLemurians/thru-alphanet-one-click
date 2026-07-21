.PHONY: install full account demo verify

install:
	sudo -H bash install.sh

full:
	sudo -H bash install.sh --full

account:
	sudo -H bash scripts/account.sh

demo:
	sudo -H bash scripts/build_upload.sh

verify:
	sudo -H bash verify.sh
