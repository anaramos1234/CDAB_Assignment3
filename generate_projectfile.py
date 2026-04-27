import json
import os
import uuid
import random
from datetime import datetime, timedelta

output_dir = "project_files"
os.makedirs(output_dir, exist_ok=True)

execution_nodes = ["cresselia", "darkrai", "mewtwo", "lugia"]

base_time = datetime(2026, 4, 27, 8, 0, 0)

for i in range(1, 101):
    sample_id = f"3D_{100+i}_S{random.randint(1, 5)}"
    node = random.choice(execution_nodes)
    
    start_time = base_time + timedelta(minutes=i*5)
    duration_minutes = random.randint(2, 15)
    end_time = start_time + timedelta(minutes=duration_minutes)
    
    # Simulate integrity checks 
    sha256_status = "La suma coincide" if random.random() > 0.1 else "ERROR: Checksum mismatch"
    seqfu_status = "OK PE" if random.random() > 0.1 else "FAILED"
    
    # Simulate file size for Throughput monitoring
    size_bytes = random.randint(1_000_000_000, 5_000_000_000)
    
    # Estructura JSON-LD 
    provenance_record = {
        "@context": "http://www.w3.org/ns/prov#",
        "@id": f"urn:uuid:{uuid.uuid4()}",
        "@type": "Activity",
        "label": f"Processament complet de {sample_id}",
        "startTime": start_time.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "endTime": end_time.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "executionNode": node,
        "sourceDirectory": "/data/input/",
        "destinationDirectory": f"/data/output/{sample_id}",
        "wasAssociatedWith": [
            {
                "@type": "SoftwareAgent",
                "label": "seqfu",
                "version": "1.22.3"
            },
            {
                "@type": "SoftwareAgent",
                "label": "sha256sum",
                "version": "sha256sum (GNU coreutils) 8.32"
            },
            {
                "@type": "SoftwareAgent",
                "label": "Pipeline Nextflow fastq_prov",
                "repository": "local",
                "commitId": "N/A",
                "revision": "N/A"
            },
            {
                "@id": "urn:person:salle_alumni",
                "@type": "Person",
                "label": "Usuari executor: salle_alumni",
                "actedOnBehalfOf": {
                    "@id": "https://ror.org/01y990p52",
                    "@type": "Organization",
                    "label": "La Salle"
                }
            }
        ],
        "generated": [
            {
                "@type": "Entity",
                "label": "Verificació SHA256",
                "description": "Resultat de la comprovació de checksum a destí",
                "value": f"{sample_id}_R1_001.fastq.gz: {sha256_status} {sample_id}_R2_001.fastq.gz: {sha256_status}"
            },
            {
                "@type": "Entity",
                "label": "Verificació Seqfu",
                "description": "Resultat de la comprovació d'integritat del format FASTQ",
                "value": f"{seqfu_status} {sample_id}_R1_001.fastq.gz 0 0 0"
            },
            {
                "@type": "Entity",
                "label": "FASTQ Files",
                "totalSizeBytes": str(size_bytes),
                "category": "Genet",
                "fileCount": "2"
            }
        ]
    }
    
    file_name = f"provenance_log_{i:03d}.json"
    file_path = os.path.join(output_dir, file_name)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(provenance_record, f, indent=2, ensure_ascii=False)

print(f"Success! 100 JSON-LD files have been generated in the '{output_dir}' directory.")