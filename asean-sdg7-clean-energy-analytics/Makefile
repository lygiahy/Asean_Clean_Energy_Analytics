.PHONY: all slice index clean

PY ?= python3

all: slice index

slice:
	$(PY) 01-renewable-capacity-slice/scripts/run_pipeline.py --check

index:
	$(PY) 02-investment-priority-index/scripts/build_database.py --check --quiet

clean:
	rm -rf 01-renewable-capacity-slice/output 02-investment-priority-index/output
