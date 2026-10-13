.PHONY: test demo

test:
	sh scripts/run_tests.sh

demo:
	WAVE=1 sh scripts/run_tests.sh demo
