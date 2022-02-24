library(tidyverse)
library(ggplot2)
library(lubridate)

#adf_file = "M07_adf_33469_2022-01-28_13-22-38.csv"
adf_file = "M05_adf_33508_2022-02-02_11-04-39.csv"

read_csv(adf_file, skip=4) ->
  ad

ad %>% 
  mutate(datetime = parse_datetime(`GMT Time`, "%m/%d/%Y %I:%M:%S %p")) %>%
  select(-`GMT Time`) %>%
  mutate(hour = hour(with_tz(datetime, "America/Los_Angeles"))) %>% 
  group_by(hour) %>% 
  summarise(total = sum(ODBA)) %>% 
  ungroup %>% 
  ggplot(aes(x=hour, y=total)) + geom_bar(stat="identity")


ad %>% 
  ggplot(aes(x=`Temperature [C]`,y=ODBA)) + geom_point()
