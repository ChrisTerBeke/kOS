"""KerboScript / kOS language runtime."""

from kos_runtime.parser import parse_script
from kos_runtime.vm import VirtualMachine

__all__ = ["parse_script", "VirtualMachine"]
