#!/bin/bash

az login --service-principal -u "$SP_USER" -p "$SP_PASSWORD" --tenant "$SP_TENANT"

endDates=$(az ad app list --all | jq '.[] | .displayName + ":" + .id + ":" + .passwordCredentials[].endDateTime');


eval '
for date in '$endDates';
do
  tmpdate=$(echo "$date" | cut -d ":" -f3 | cut -d "T" -f1)
  cond=$(date -d "$tmpdate" +%s)
  today=$(date +%s)
  nextweek=$(date -d "next week" +%s)
  nextmonth=$(date -d "next month" +%s)

  service=$(echo "$date" | cut -d ":" -f1)
  id=$(echo "$date" | cut -d ":" -f2)
  expire_date=$(echo "$date" | cut -d ":" -f3)

  expire_in="YEAR"
  if [ $today -ge $cond ];
  then
	expire_in="NOW"
  elif [ $nextweek -ge $cond ];
  then
	expire_in="WEEK"
  elif [ $nextmonth -ge $cond ];
  then
	expire_in="MONTH"
  fi

  echo "{\"service\":\"$service\",\"id\":\"$id\",\"expire_date\":\"$expire_date\",\"expire_in\":\"$expire_in\"}"
done'
