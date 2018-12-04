# standardSQL
# owner: aaronc@thumbtack.com, grace@thumbtack.com, vishesh@thumbtack.com
# start_date: 2015-01-01
# window: 1
# description: Combines and standardizes data from the Search Query Performance Reports
#   from Google Ads (marketing.g_search_query_performance) and Bing Ads (marketing.b_search_query_performance)
# column description:
#  account_id: "Identifier for customer account within MCC (aka CID). Called "account_descriptive_name" in Google Ads"
#  account_name: "Name of customer account within MCC
#  average_position: "Average position of all impressions for the keyword"
#  conversion_value: "[Google Ads only] Conversion value in USD as reported in by offline conversion upload and values assigned to conversions tracked online (2018-11-25: In-app actions only)"
#  cost: "Cost in USD. Called "spend" in Bing Ads"
#  device: "Device, standardized to "computer", "smartphone" and "tablet"
#  final_url: "Landing page URL"
#  keyword_text: [Google] the keyword text the query matched to. [Bing] the keyword
#  match_type: "Match type for the keyword (standardized to include "bmm" for Broad keywords containing the "+" modifier)"
#  platform: "Advertising platform ("google" or "bing")"
#  query: The search query used

WITH google AS
(
  SELECT
      external_customer_id AS account_id,
      account_descriptive_name AS account_name,
      ad_group_id,
      ad_group_name,
      ad_group_status,
      average_position,
      campaign_id,
      campaign_name,
      campaign_status,
      CAST(clicks AS FLOAT64) AS clicks,
      conversions,
      conversion_value,
      ROUND(CAST(cost AS FLOAT64) / 1000000, 2) AS cost,
      CAST(date AS date) AS date,
      CASE
        WHEN device = 'Tablets with full browsers' THEN 'tablet'
        WHEN device = 'Mobile devices with full browsers' THEN 'smartphone'
        WHEN device = 'Computers' THEN 'computer'
        ELSE 'other'
      END AS device,
      CASE
        WHEN final_url = '' THEN NULL
        WHEN final_url = "--" THEN NULL
        WHEN SUBSTR(final_url, 0, 1) <> '[' THEN final_url
        ELSE SUBSTR(final_url, 3, LENGTH(final_url) - 4)
      END AS final_url,
      impressions,
      keyword_id,
      keyword_text_matching_query AS keyword_text,
      REPLACE(query_match_type_with_variant,' (close variant)','') AS match_type,
      query
    FROM marketing.g_search_query_performance
    WHERE NOT (account_descriptive_name = 'Thumbtack' AND campaign_name <> 'Branded' AND CAST(date AS date) >= '2018-09-03')
    AND NOT (account_descriptive_name LIKE '%5500%' AND CAST(date AS date) >= '2018-07-31')
),
bing AS
(
  SELECT
      account_id,
      account_name,
      ad_group_id,
      ad_group_name,
      ad_group_status,
      CAST(average_position AS FLOAT64) AS average_position,
      campaign_id,
      campaign_name,
      CASE
        WHEN campaign_status = 'Active' THEN 'enabled'
        WHEN campaign_status = 'Paused' THEN 'paused'
        ELSE 'other'
      END campaign_status,
      CAST(clicks AS FLOAT64) AS clicks,
      CAST(conversions AS FLOAT64) AS conversions,
      revenue AS conversion_value,
      CAST(spend AS FLOAT64) AS cost,
      CAST(time_period AS date) AS date,
      CASE
        WHEN device_type = 'Tablet' THEN 'tablet'
        WHEN device_type = 'Smartphone' THEN 'smartphone'
        WHEN device_type = 'Computer' THEN 'computer'
        ELSE 'other'
      END AS device,
      destination_url AS final_url,
      impressions,
      CAST(keyword_id AS STRING) AS keyword_id,
      keyword AS keyword_text,
      delivered_match_type AS match_type,
      search_query AS query
    FROM marketing.b_search_query_performance
    WHERE NOT (account_name = 'Thumbtack' AND campaign_name <> 'Branded' AND CAST(time_period AS date) >= '2018-08-11') -- verify date
    AND NOT (account_name LIKE '%5500%' AND CAST(time_period AS date) >= '2018-08-12')
)
SELECT
  account_id,
  account_name,
  ad_group_id,
  ad_group_name,
  ad_group_status,
  average_position,
  campaign_id,
  campaign_name,
  campaign_status,
  clicks,
  conversions,
  conversion_value,
  cost,
  date,
  device,
  NULL AS device_os,
  final_url,
  impressions,
  keyword_id,
  keyword_text,
  match_type,
  query,
  'google' AS platform
FROM google
UNION ALL
SELECT
  account_id,
  account_name,
  ad_group_id,
  ad_group_name,
  ad_group_status,
  average_position,
  campaign_id,
  campaign_name,
  campaign_status,
  clicks,
  conversions,
  conversion_value,
  cost,
  date,
  device,
  NULL AS device_os,
  final_url,
  impressions,
  keyword_id,
  keyword_text,
  match_type,
  query,
  'bing' AS platform
FROM bing
