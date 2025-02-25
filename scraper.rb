require 'nokogiri'
require 'open-uri'
require 'sqlite3'
require 'logger'
require 'date'
require 'cgi'

# Set up a logger to log the scraped data
logger = Logger.new(STDOUT)

# URL of the Glenorchy City Council planning applications page
url = "https://northernmidlands.tas.gov.au/planning/development-in-the-northern-midlands/development-applications-2"

# Step 1: Fetch the page content
begin
  logger.info("Fetching page content from: #{url}")
  page_html = open(url).read
  logger.info("Successfully fetched page content.")
rescue => e
  logger.error("Failed to fetch page content: #{e}")
  exit
end

# Step 2: Parse the page content using Nokogiri
doc = Nokogiri::HTML(page_html)

# Step 3: Initialize the SQLite database
db = SQLite3::Database.new "data.sqlite"

logger.info("Create table")
# Create table
db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS northernmidlands (
    id INTEGER PRIMARY KEY,
    description TEXT,
    date_scraped TEXT,
    date_received TEXT,
    on_notice_to TEXT,
    address TEXT,
    council_reference TEXT,
    applicant TEXT,
    owner TEXT,
    stage_description TEXT,
    stage_status TEXT,
    document_description TEXT,
    title_reference TEXT
  );
SQL

# Define variables for storing extracted data for each entry
address = ''  
description = ''
on_notice_to = ''
title_reference = ''
date_received = ''
council_reference = ''
applicant = ''
owner = ''
stage_description = ''
stage_status = ''
document_description = ''
date_scraped = Date.today.to_s


logger.info("Start Extraction of Data")

# Parse the content to get all the planning applications
page.search('.tab-pane .generic-list__item').each do |listing|
  # Extract the details for each planning application
  title = listing.at('.generic-list__title a').text.strip
  pdf_url = listing.at('.generic-list__title a')['href']
  submission_date = listing.at('span').text.match(/submissions by (\d{1,2}\/\d{1,2}\/\d{4})/)[1]  # Extract submission deadline

  # Construct the PDF link by checking if the URL is absolute or relative
  pdf_url = URI.join(url, pdf_url).to_s

  # Extract the council_reference, address, description, and submission deadline
  council_reference = title.match(/(PLN-\d{2}-\d{4})/)[0]  # Extract reference code like PLN-24-0109
  address = title.match(/(?:PLN-\d{2}-\d{4})\s*-\s*(.*?):/)[1]  # Extract address (text before ':')
  description = title.match(/:\s*(.*)/)[1]  # Extract description (text after ':')
  on_notice_to = submission_date  # Submission deadline as on_notice_to

  # Output the extracted information
  puts "Council Reference: #{council_reference}"
  puts "Address: #{address}"
  puts "Description: #{description}"
  puts "On Notice To: #{on_notice_to}"
  puts "PDF Link: #{pdf_url}"
  puts "-----------------------------------"
end
