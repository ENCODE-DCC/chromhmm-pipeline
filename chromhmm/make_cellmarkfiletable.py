import json
from pathlib import Path

import typer


def main(
    input_file: Path = typer.Option(exists=True), output_path: Path = typer.Option(...)
) -> None:
    with input_file.open() as f:
        data = json.load(f)
    print(data)


if __name__ == "__main__":
    typer.run(main)
