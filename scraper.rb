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

# Find the div with the id "current-development-applications"
applications_div = doc.at('#current-development-applications')

# Extract closing date (on_notice_to) from <h2>
on_notice_to_element = applications_div.at('h2')
on_notice_to = on_notice_to_element ? on_notice_to_element.text.strip : nil

# Extract the individual planning applications
applications_div.search('p a').each do |listing|
  # Extract title and description (title and address)
  title_element = listing.at('strong')
  title = title_element ? title_element.text.strip : nil

  # Add safety checks to avoid nil errors when using regular expressions
  if title
    council_reference_match = title.match(/(PLN-\d{2}-\d{4})/)
    council_reference = council_reference_match ? council_reference_match[0] : nil

    address_match = title.match(/(?:PLN-\d{2}-\d{4})\s*-\s*(.*?):/)
    address = address_match ? address_match[1] : nil

    description_match = title.match(/:\s*(.*)/)
    description = description_match ? description_match[1] : nil
  end

  # Extract the PDF link (href)
  pdf_url = listing['href']

  # Output the extracted information
  logger.info("Council Reference: #{council_reference}")
  logger.info("Address: #{address}")
  logger.info("Description: #{description}")
  logger.info("On Notice To: #{on_notice_to}")
  logger.info("PDF Link: #{pdf_url}")
  logger.info("-----------------------------------")
end
