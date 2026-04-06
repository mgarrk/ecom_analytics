import pandas as pd
from sqlalchemy import create_engine

# Загрузка исходного CSV в PostgreSQL 

df = pd.read_csv("events.csv")

engine = create_engine("postgresql://user:password@localhost:5432/petdb26")

df.to_sql("raw_events", engine, if_exists="replace", index=False)
