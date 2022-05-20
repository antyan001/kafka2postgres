#!/usr/bin/python3

from kafka import KafkaConsumer
from json import loads
from time import sleep
import psycopg2
import pandas as pd
import re
from src import PostGresDB, PostGresLoader

TBL_NAME="yahoo_aapl_ticker_real_time"
bootstrap_servers = ['localhost:9092']
topicName = 'postgres-topic'
BATCH_SIZE__ = 100

def createTblPostgres(db, val, cols):
    df = pd.DataFrame(data=[val], columns=cols)

    # datetime_cols = []
    # find_datetime = re.compile("\d{4}\-\d{2}\-\d{2}\s*\d{2}\:\d{2}\:\d{2}\.?\d{1,6}?")
    #
    # for col in df.columns:
    #     touch_df_rec = df[col][df[col].first_valid_index()]
    #     try:
    #         out = find_datetime.findall(touch_df_rec)
    #         if len(out) > 0:
    #             datetime_cols.append(col)
    #     except:
    #         pass
    #
    # if len(datetime_cols) > 0:
    #     for col in datetime_cols:
    #         df[col] = df[col].apply(lambda x: pd.to_datetime(x))
    #
    # ###########################################################################
    # ## !!!!!!!!!!!!!!!!!!! REPLACING pd.NaT VALUES WITH None!!!!!!!!!!!!!!!!!##
    # ###########################################################################
    # for col in datetime_cols:
    #     df[col] = df[col].astype(object).where(df[col].notnull(), None)
    #     # df.replace({np.NaN: pd.to_datetime(NAT_SUBST_STR__)}, inplace = True)
    #     # df = df.replace({pd.NaT: None}).replace({np.NaN: None})
    #
    # values_list = df.values.tolist()
    # cols_lst = df.columns.tolist()

    ## Types auto mapping between pandas and Postrgres and `CREATE TABLE` clause builder
    cr_sql_query = loader.dataTypeMapping(df)

    ## CREATE Table following with Bulk Isert Into
    print("Droppping existed table...")
    cur = db.cursor
    cur.execute("DROP TABLE IF EXISTS {} ".format(TBL_NAME))

    print("Creating new table with casted data types...")
    print(cr_sql_query)
    query = cr_sql_query.format(TBL_NAME)

    cur.execute(query)
    db.connection.commit()
    # db.close()

def block_iterator(iterator, size):
    bucket = list()
    for e in iterator:
        event_data = e.value
        bucket.append(event_data)
        if len(bucket) >= size:
            yield bucket
            bucket = list()

    if bucket:
        yield bucket



if __name__ == '__main__':

    loader = PostGresLoader()

    ## Connect to PostrGres DB
    db = PostGresDB(host="65.108.56.136", user="anthony", password="lolkek123", database="etldb")
    db.connect()
    cur = db.cursor

    query = \
    '''
    SELECT column_name
      FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name   = '{}'
    '''.format(TBL_NAME)

    cur.execute(query)
    cols_lst = [col[0] for col in cur.fetchall()]

    print(cols_lst)

    consumer = KafkaConsumer(
        topicName,
        bootstrap_servers=bootstrap_servers,
        auto_offset_reset='earliest',
        enable_auto_commit=True,
        group_id='my-group-id',
        value_deserializer=lambda x: loads(x.decode('utf-8'))
    )

    isnewbatch=True
    for batch in block_iterator(consumer, BATCH_SIZE__):
        # vals = [list(map(str, ele)) for ele in batch]
        vals = batch
        if isnewbatch:
            createTblPostgres(db, vals[0], cols_lst)
            isnewbatch=False
        loader.db_insert_batch(cur, TBL_NAME, cols_lst, vals)
        db.connection.commit()
        # sleep(1)

    db.close()