"""Read only: capture this run's local Firestore emulator plant documents."""

import datetime
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parent
PROJECT = "plantcare-ai-dev-tasnimalam"
UID = "tXwYOri17uDhuIc8uLfZYYzyUqIi"
BASE = f"http://127.0.0.1:8080/v1/projects/{PROJECT}/databases/(default)/documents"
FIELDS = {
    "commonName", "scientificName", "environment", "growingMedium",
    "potSizeLiters", "sunlight", "growthStage", "notes", "createdAt", "updatedAt",
}


def read(path):
    request = urllib.request.Request(
        BASE + path, headers={"Authorization": "Bearer owner"}
    )
    with urllib.request.urlopen(request) as response:
        return json.load(response)


documents = read(f"/users/{UID}/plants").get("documents", [])
assert documents, "No saved plants found"
for document in documents:
    assert set(document["fields"]) == FIELDS, document["name"]
    for field in ("createdAt", "updatedAt"):
        assert "timestampValue" in document["fields"][field]

evidence = {
    "capturedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "backend": "Local Firestore emulator; read with emulator admin credential",
    "projectId": PROJECT,
    "userId": UID,
    "assertions": {
        "plantCount": len(documents),
        "exactExistingPlantFields": True,
        "timestampFieldsHaveTimestampValues": True,
        "photoAbsentFromSavedPlantDocuments": True,
        "identificationMetadataAbsentFromSavedPlantDocuments": True,
    },
    "scope": "The saved plant documents. This is not a production backend audit.",
    "documents": documents,
}
(ROOT / "firestore-evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
print(json.dumps(evidence["assertions"], indent=2))
