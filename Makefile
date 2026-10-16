.PHONY: test demo

test:
	sh scripts/run_tests.sh
	python3 scripts/test_build_ise.py

demo:
	WAVE=1 sh scripts/run_tests.sh demo
