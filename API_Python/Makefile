.PHONY: venv install run dev

venv:
	python3 -m venv .venv

install:
	./.venv/bin/pip install --upgrade pip
	./.venv/bin/pip install -r requirements.txt

run:
	./.venv/bin/python -m app.main

dev:
	./.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
