import csv
with open("hsk30.csv", "r", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    headers = reader.fieldnames
    print("Columnas:", headers)
    # Ver las primeras 5 filas
    for i, row in enumerate(reader):
        print(row)
        if i >= 4: break