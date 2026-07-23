"""Read the field map (data dictionary) and the Missoula taxlot geodatabase.

Requires geopandas — run with the housing_project conda env:
    /opt/anaconda3/envs/housing_project/bin/python read_data.py
"""

from pathlib import Path

import pandas as pd
import geopandas as gpd

# data/ folder sits next to code/, so anchor to this file rather than the cwd
data = Path(__file__).parent.parent / "data"

# Data dictionary
field_map = pd.read_csv("data/FieldMap.csv")
print(field_map)

# Taxlot layer (Esri File Geodatabase)
taxlots = gpd.read_file(data / "HiringExercise_GIS_2024.gdb")
print(taxlots.info())
print(taxlots.head())
