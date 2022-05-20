#!/usr/bin/python3

from time import sleep
import requests
import json
from collections import OrderedDict
from datetime import datetime, timedelta
import re
from kafka import KafkaProducer

def get_headers(ticker ="AAPL"):
    cookie_str =\
    '''
    B=aeo302lh2b4ga&b=3&s=l9; 
    GUC=AQEBAQFiJuNiL0IdagQv; 
    A1=d=AQABBAqSJWICEBCfINe2DEY7izyobxVgYKcFEgEBAQHjJmIvYgAAAAAA_eMAAAcICpIlYhVgYKc&S=AQAAAi4UtceZuMD5Hnt9UNxMb6A; 
    A3=d=AQABBAqSJWICEBCfINe2DEY7izyobxVgYKcFEgEBAQHjJmIvYgAAAAAA_eMAAAcICpIlYhVgYKc&S=AQAAAi4UtceZuMD5Hnt9UNxMb6A; 
    A1S=d=AQABBAqSJWICEBCfINe2DEY7izyobxVgYKcFEgEBAQHjJmIvYgAAAAAA_eMAAAcICpIlYhVgYKc&S=AQAAAi4UtceZuMD5Hnt9UNxMb6A&j=WORLD; 
    cmp=t=1646634514&j=0; PRF=t%3DAAPL%252BES%253DF
    '''
    return {
                "scheme": "https",
                "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9",
                "accept-encoding": "gzip, deflate, br",
                "accept-language": "en-GB,en;q=0.9,en-US;q=0.8,ml;q=0.7",
                "cache-control": "max-age=0",
                "sec-ch-ua": '"Not A;Brand";v="99", "Chromium";v="98", "Google Chrome";v="98"',
                "sec-ch-ua-mobile": "?0",
                "sec-fetch-dest": "empty",
                "sec-fetch-mode": "cors",
                "sec-fetch-site": "same-site",
                "cookie": re.sub("\n\s+"," ",cookie_str).strip(),
                "origin": "https://finance.yahoo.com",
                "referer": "https://finance.yahoo.com/quote/{0}/chart?p={0}".format(ticker),
                "user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.102 Safari/537.36"
           }


bootstrap_servers = ['localhost:9092']
topicName = 'postgres-topic'
ticker ="AAPL"

# Initialize Kafka Producer
producer = KafkaProducer(bootstrap_servers=bootstrap_servers,
                         value_serializer=lambda x:
                         json.dumps(x).encode('utf-8'))

dt = datetime.now()
dm1 = dt - timedelta(minutes=0, seconds=dt.second, microseconds=dt.microsecond)
dm0 = dm1 - timedelta(days=7, minutes=0, seconds=0, microseconds=0)
curr_dttm0 = int(datetime.timestamp(dm0))
curr_dttm1 = int(datetime.timestamp(dm1))

# Parse Yahoo Financial Chart
query_chart = "https://query2.finance.yahoo.com/v8/finance/chart/AAPL?symbol=AAPL\
                     &period1={0}&period2={1}\
                     &useYfid=true\
                     &interval=1m\
                     &includePrePost=true\
                     &events=div%7Csplit%7Cearn\
                     &lang=en-US&region=US\
                     &crumb=lkTjQHrTxZC\
                     &corsDomain=finance.yahoo.com".format(curr_dttm0,curr_dttm1)

chart_query = re.sub("\n?\s+","",query_chart).strip()
chart_json_response = requests.get(chart_query, verify=False, headers=get_headers(), timeout=50)

# Fetched Data PostProcessing
json_loaded_chart = json.loads(chart_json_response.text)

summary_data = OrderedDict()
ts = json_loaded_chart['chart']['result'][0]["timestamp"]
summary_data['ts'] = [datetime.strftime(ts, format="%Y:%m:%d %H:%M:%S")
                                        for ts in map(datetime.fromtimestamp, ts)]
quotes = json_loaded_chart['chart']['result'][0]['indicators']['quote'][0]
meta_keys = quotes.keys()
for key in meta_keys:
    summary_data[key] = quotes[key]

data_tuples = \
zip(summary_data["ts"],
     summary_data["close"],
     summary_data["open"],
     summary_data["low"],
     summary_data["high"],
     summary_data["volume"]
    )

# Public a message in Kafka Topic
for line in data_tuples:
    print(line)
    producer.send(topicName, line)
    producer.flush()
    sleep(0.1)