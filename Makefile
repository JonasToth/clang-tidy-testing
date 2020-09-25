# Test the functionality of the files provided by this project.
.PHONY: test
test:
	bash src/workstep.bash
	bash src/run_clang_tidy.bash
