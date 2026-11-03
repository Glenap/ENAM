"""FINN — a financial investment agent. Show less, mean more.

The backend is a snapshot-first data layer: everything the API serves was
written to SQLite by the seeding pipeline, and nothing is fetched or generated
at request time. That property is what keeps the demo alive when an exchange
blocks us or a data source rate-limits.

Read backend/README.md before reading the code. It states what is reconstructed
from the handover and what is not.
"""

__version__ = "1.0.0"
