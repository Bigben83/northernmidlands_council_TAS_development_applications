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
applications_div.search('p').each do |listing|
  # First <a> link with <strong> for council reference and address
  first_a_tag = listing.at('a')
  if first_a_tag
    title_element = first_a_tag.at('strong')
    title = title_element ? title_element.text.strip : nil

    # Add safety checks to avoid nil errors when using regular expressions
    if title
      # Extract council reference
      council_reference_match = title.match(/(PLN-\d{2}-\d{4})/)
      council_reference = council_reference_match ? council_reference_match[0] : nil

      # Extract address (text after the hyphen and before the colon)
      address_match = title.match(/(?:PLN-\d{2}-\d{4})\s*-\s*(.*?),\s*(.*)/)
      if address_match
        address = "#{address_match[1]}, #{address_match[2]}"  # Combining street and suburb
      end

      # Extract description (text after the colon)
      description_match = title.match(/:\s*(.*)/)
      description = description_match ? description_match[1] : nil
    end
  end

  # Second <a> link with <span> for title reference and description
  second_a_tag = listing.at('a:nth-child(2)')
  if second_a_tag
    second_span = second_a_tag.at('span')
    second_text = second_span ? second_span.text.strip : nil

    # Extract title reference (e.g., (CT 21938/12))
    title_reference_match = second_text.match(/\((.*?)\)/)
    title_reference = title_reference_match ? title_reference_match[1] : nil

    # Extract description (the text after the first hyphen in the span)
    description_match = second_text.match(/-\s*(.*)/)
    description = description_match ? description_match[1] : description  # Retain first description if empty
  end

  # Extract the PDF link (href)
  pdf_url = first_a_tag['href'] if first_a_tag
  
  # Step 6: Ensure the entry does not already exist before inserting
  existing_entry = db.execute("SELECT * FROM northernmidlands WHERE council_reference = ?", council_reference )

  # if existing_entry.empty? # Only insert if the entry doesn't already exist
  # Step 5: Insert the data into the database
  db.execute("INSERT INTO northernmidlands (address, on_notice_to, description, document_description, council_reference, title_reference, date_scraped)
              VALUES (?, ?, ?, ?, ?, ?, ?)", [address, on_notice_to, description, document_description, council_reference, title_reference, date_scraped])

  logger.info("Data for #{council_reference} saved to database.")
    else
      logger.info("Duplicate entry for application #{council_reference} found. Skipping insertion.")
    end
  # Output the extracted information
  logger.info("Council Reference: #{council_reference}")
  logger.info("Address: #{address}")
  logger.info("Description: #{description}")
  logger.info("On Notice To: #{on_notice_to}")
  logger.info("PDF Link: #{pdf_url}")
  logger.info("Title Reference: #{title_reference}")
  logger.info("-----------------------------------")
end
