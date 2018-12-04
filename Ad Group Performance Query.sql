# standardSQL
# owner: aaronc@thumbtack.com, grace@thumbtack.com, vishesh@thumbtack.com
# start_date: 2015-01-01
# window: 1
# description: Combines and standardizes data from the Adgroup Performance Reports
#   from Google Ads (marketing.g_adgroup_performance) and Bing Ads (marketing.b_adgroup_performance)
# column description:
#  account_id: "Identifier for customer account within MCC (aka CID). Called "account_descriptive_name" in Google Ads"
#  account_name: "Name of customer account within MCC
#  average_position: "Average position of all impressions for the keyword"
#  bidding_strategy_type: "Type of bid strategy (i.e. Manual CPC, Target CPA, etc)"
#  conversion_value: "[Google Ads only] Conversion value in USD as reported in by offline conversion upload and values assigned to conversions tracked online (2018-11-25: In-app actions only)"
#  cost: "Cost in USD. Called "spend" in Bing Ads"
#  cpc_bid: "Maximum cost per click bid"
#  device: "Device, standardized to "computer", "smartphone" and "tablet"
#  device_os: "[Bing Ads only] Device operating system"
#  impression_share: "[Google Ads only] Impressions received divided by the estimated number of impressions eligible to receive (standardized to remove string representing fewer than 10% impression share)"
#  impression_share_raw: "[Google Ads only] Impressions received divided by the estimated number of impressions eligible to receive (raw string)"
#  impression_share_exact: "[Google Ads only] Impressions received divided by the estimated number of impressions eligible to receive for search terms that matched keyword exactly (standardized to remove string representing fewer than 10% impression share)"
#  impression_share_exact_raw: "[Google Ads only] Impressions received divided by the estimated number of impressions eligible to receive for search terms that matched keyword exactly (raw string)"
#  impression_share_lost_rank: "[Google Ads only] Estimated percentage of impressions that ads didn't receive due to poor ad rank (standardized to remove string representing fewer than 10% impression share)"
#  impression_share_lost_rank_raw: "[Google Ads only] Estimated percentage of impressions that ads didn't receive due to poor ad rank (raw string)"
#  platform: "Advertising platform ("google" or "bing")"

WITH google AS
(
  SELECT
      external_customer_id AS account_id,
      account_descriptive_name AS account_name,
      ad_group_id,
      ad_group_name,
      ad_group_status,
      average_position,
      LOWER(bidding_strategy_type) AS bidding_strategy_type,
      campaign_id,
      campaign_name,
      campaign_status,
      CAST(clicks AS FLOAT64) AS clicks,
      conversions,
      conversion_value,
      ROUND(CAST(cost AS FLOAT64) / 1000000, 2) AS cost,
      ROUND(SAFE_CAST(REPLACE(cpc_bid, 'auto: ', '') AS FLOAT64) / 1000000, 2) AS cpc_bid,
      CAST(date AS date) AS date,
      CASE
        WHEN device = 'Tablets with full browsers' THEN 'tablet'
        WHEN device = 'Mobile devices with full browsers' THEN 'smartphone'
        WHEN device = 'Computers' THEN 'computer'
        ELSE 'other'
      END AS device,
      impressions,
      CASE
        WHEN search_impression_share = '< 10%' THEN NULL
        WHEN search_impression_share = ' --' THEN NULL
        ELSE ROUND(SAFE_CAST(REPLACE(search_impression_share, '%', '') AS FLOAT64) / 100, 4)
      END AS impression_share,
      search_impression_share AS impression_share_raw,
      CASE
        WHEN search_exact_match_impression_share = '< 10%' THEN NULL
        WHEN search_exact_match_impression_share = ' --' THEN NULL
        ELSE ROUND(SAFE_CAST(REPLACE(search_exact_match_impression_share, '%', '') AS FLOAT64) / 100, 4)
      END AS impression_share_exact,
      search_exact_match_impression_share AS impression_share_exact_raw,
      CASE
        WHEN search_rank_lost_impression_share = '> 90%' THEN NULL
        WHEN search_rank_lost_impression_share = ' --' THEN NULL
        ELSE ROUND(SAFE_CAST(REPLACE(search_rank_lost_impression_share, '%', '') AS FLOAT64) / 100, 4)
      END AS impression_share_lost_rank,
      search_rank_lost_impression_share AS impression_share_lost_rank_raw,
      label_ids,
      labels,
      CASE
        WHEN target_cpa like '%auto%' THEN NULL
        WHEN target_cpa NOT LIKE '%\\"%' THEN ROUND(SAFE_CAST(target_cpa AS FLOAT64) / 1000000, 2)
        ELSE NULL
      END AS target_cpa
    FROM marketing.g_adgroup_performance
    WHERE NOT (account_descriptive_name = 'Thumbtack' AND campaign_name <> 'Branded' AND CAST(date AS date) >= '2018-09-03')
      AND NOT (account_descriptive_name LIKE '%5500%' AND CAST(date AS date) >= '2018-07-31')
      AND impressions > 0
),
bing AS
(
  SELECT
      account_id,
      '' AS account_name,
      ad_group_id,
      ad_group_name,
      '' AS ad_group_status,
      CAST(average_position AS FLOAT64) AS average_position,
      '' AS bidding_strategy_type,
      campaign_id,
      campaign_name,
      CASE
        WHEN campaign_status = 'Active' THEN 'enabled'
        WHEN campaign_status = 'Paused' THEN 'paused'
        ELSE 'other'
      END campaign_status,
      CAST(clicks AS FLOAT64) AS clicks,
      CAST(conversions AS FLOAT64) AS conversions,
      CAST(spend AS FLOAT64) AS cost,
      NULL AS cpc_bid,
      CAST(PARTITIONTIME AS date) AS date,
      LOWER(device_os) AS device_os,
      LOWER(delivered_match_type) AS delivered_match_type,
      CASE
        WHEN device_type = 'Tablet' THEN 'tablet'
        WHEN device_type = 'Smartphone' THEN 'smartphone'
        WHEN device_type = 'Computer' THEN 'computer'
        ELSE 'other'
      END AS device,
      true AS has_quality_score,
      impressions,
      quality_score,
      CASE
        WHEN ad_relevance IS NULL OR ad_relevance = 0 THEN NULL
        WHEN ad_relevance = 3 THEN 'above average'
        WHEN ad_relevance = 2 THEN 'average'
        WHEN ad_relevance = 1 THEN 'below average'
        ELSE 'other'
      END AS quality_score_ad_relevance,
      CASE
        WHEN landing_page_experience IS NULL OR landing_page_experience = 0 THEN NULL
        WHEN landing_page_experience = 3 THEN 'above average'
        WHEN landing_page_experience = 2 THEN 'average'
        WHEN landing_page_experience = 1 THEN 'below average'
        ELSE 'other'
      END AS quality_score_landing_page,
      CASE
        WHEN expected_ctr IS NULL OR expected_ctr = 0 THEN NULL
        WHEN expected_ctr = 3 THEN 'above average'
        WHEN expected_ctr = 2 THEN 'average'
        WHEN expected_ctr = 1 THEN 'below average'
        ELSE 'other'
      END AS quality_score_predicted_ctr
    FROM marketing.b_adgroup_performance
    WHERE NOT (campaign_name <> 'Branded' AND CAST(PARTITIONTIME AS date) >= '2018-08-11')
      AND NOT (CAST(PARTITIONTIME AS date) >= '2018-08-12')
      AND impressions > 0
)
SELECT
  account_id,
  account_name,
  ad_group_id,
  ad_group_name,
  ad_group_status,
  average_position,
  bidding_strategy_type,
  campaign_id,
  campaign_name,
  campaign_status,
  clicks,
  conversions,
  conversion_value,
  cost,
  cpc_bid,
  date,
  device,
  NULL AS device_os,
  impressions,
  impression_share,
  impression_share_raw,
  impression_share_exact,
  impression_share_exact_raw,
  impression_share_lost_rank,
  impression_share_lost_rank_raw,
  label_ids,
  labels,
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
  bidding_strategy_type,
  campaign_id,
  campaign_name,
  campaign_status,
  clicks,
  conversions,
  NULL AS conversion_value,
  cost,
  cpc_bid,
  date,
  device,
  NULL AS device_os,
  impressions,
  NULL AS impression_share,
  NULL AS impression_share_raw,
  NULL AS impression_share_exact,
  NULL AS impression_share_exact_raw,
  NULL AS impression_share_lost_rank,
  NULL AS impression_share_lost_rank_raw,
  NULL AS label_ids,
  NULL AS labels,
  'bing' AS platform
FROM bing
