"""Build the Python 3.12 x86_64 Lambda artifact; run before Terraform plan."""
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def main():
    output = ROOT / "dist"
    output.mkdir(exist_ok=True)
    if "--inside" not in sys.argv:
        subprocess.run(["docker", "run", "--rm", "--platform", "linux/amd64",
                        "-v", f"{ROOT}:/src", "-w", "/src", "python:3.12-slim",
                        "python", "build.py", "--inside"], check=True)
        return
    with tempfile.TemporaryDirectory() as temporary:
        package = Path(temporary)
        subprocess.run([sys.executable, "-m", "pip", "install", "--target", str(package),
                        "-r", str(ROOT / "requirements.lock")], check=True)
        shutil.copytree(ROOT / "email_sender", package / "email_sender", ignore=shutil.ignore_patterns("__pycache__"))
        for cache in package.rglob("__pycache__"):
            shutil.rmtree(cache)
        shutil.make_archive(str(output / "email-sender"), "zip", package)
    artifact = output / "email-sender.zip"
    with zipfile.ZipFile(artifact) as archive:
        extracted = sum(item.file_size for item in archive.infolist())
    if artifact.stat().st_size >= 50 * 1024**2 or extracted >= 250 * 1024**2:
        sys.exit("Email package exceeds direct Lambda upload limits; use an S3 artifact before deploying")


if __name__ == "__main__":
    main()
