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


# Loop through each content block in the main listing
doc.search('.tab-pane .generic-list__item').each do |listing|
  # Extract the details for each planning application
  title = listing.at('.generic-list__title a').text.strip
  document_description = listing.at('.generic-list__title a')['href']
  date_received = listing.at('span').text.match(/submissions by (\d{1,2}\/\d{1,2}\/\d{4})/)[1]  # Extract submission deadline

  # Construct the PDF link by checking if the URL is absolute or relative
  document_description = URI.join(url, pdf_url).to_s

  # Extract the council_reference, address, description, and submission deadline
  council_reference = title.match(/(PLN-\d{2}-\d{4})/)[0]  # Extract reference code like PLN-24-0109
  address = title.match(/(?:PLN-\d{2}-\d{4})\s*-\s*(.*?):/)[1]  # Extract address (text before ':')
  description = title.match(/:\s*(.*)/)[1]  # Extract description (text after ':')
  on_notice_to = submission_date  # Submission deadline as on_notice_to
  
  # Step 6: Ensure the entry does not already exist before inserting
  existing_entry = db.execute("SELECT * FROM northernmidlands WHERE council_reference = ?", council_reference )

  if existing_entry.empty? # Only insert if the entry doesn't already exist
  # Step 5: Insert the data into the database
  db.execute("INSERT INTO northernmidlands (address, on_notice_to, description, document_description, date_scraped)
              VALUES (?, ?, ?, ?, ?)", [address, on_notice_to, description, document_description, date_scraped])

  logger.info("Data for #{council_reference} saved to database.")
    else
      logger.info("Duplicate entry for application #{council_reference} found. Skipping insertion.")
    end
  
  # If you need to handle additional details, such as geolocation, it can be extracted as follows:
  lat = content_block.at_css('.content-block__map-link')['data-lat']
  lng = content_block.at_css('.content-block__map-link')['data-lng']
  logger.info("Latitude: #{lat}, Longitude: #{lng}")
end
