require "adifyFileFunctions.rb"
require 'win32ole'
require 'adifyMap.rb'
require 'adifyBusinessObjects.rb'
## require 'watir' ## if RUBY_VERSION == "1.8.7" or RUBY_VERSION == "1.8.6"
require 'watir' if RUBY_VERSION == "1.9.3" or RUBY_VERSION == "1.9.2"
# require 'watir-webdriver'
require 'net/http'
require 'rubygems'
require 'json'
require 'uri'
 ##GlobalAdjustedSleepTime = 1
 GlobalAdjustedSleepTime = 1 ## 10 12  ## 3.6 ## 2.5
 LoopSleep = 0.2
 NubmerLoops = 150
 $RTBbidder = "CDS Connect Test-QA-03" ## "CDSConnect_TestCoxAuto_Deal" #Bidder 98 # "CDS Connect DealTest" #  107 # "CDS Connect Test-QA-02"   qa-3 
##  GlobalAdjustedSleepTime = 1.8
class String
  def afy11_cookie_file?
    begin
      return false if self.length < 4 or self.downcase.include?("index")
      t = ""
      fl = File.open(Watir::IE.get_special_folder_location(COOKIES)+"\\"+self,"r")
      fl.each{|l| t += l}
      fl.close
      return true if t.include?("afy11")
    rescue => e
      $logger.info("Exception in afy11_cookie_file? #{e.message}")
      return false
    end
  end
end
module Watir
  
  ## waiting for ajax on web page
  class Browser
    def wait_for_ajax(timeout=5)
      end_time = Time.now + timeout
      while self.execute_script("return jQuery.active") > 0
        sleep 0.2
        break if Time.now > end_time
      end
      self.wait(timeout + 10)
    end
  end
  class Element
    ## Determine if we can write to a DOM elem ent
    # If any parent element isn't visible then we cannot write to the
    # element  The only realiable way to determine this is to iterate
    # up the DOM elemint tree checking every element to make sure it's
    # visible
    ### ============================================================================
    def visible?
      # Now iterate up the DOM element tree and return false if any
      # parent element isn't visible or is disabled
      object = document
      while object
        begin
          if object.style.invoke('visibility') =~ /^hidden$/i
            return false
          end
          if object.style.invoke('display') =~ /^none$/i
            return false
          end
          if object.invoke('isDisabled')
            return false
          end
        rescue WIN32OLERuntimeError
          puts "Exception!"
        end
        object = object.parentElement
      end
      true
    end
    ### ============================================================================
    def writable?
      assert_exists
      # First make sure the element itself is writable
      begin
        assert_enabled
        assert_not_readonly
      rescue Watir::Exception::ObjectDisabledException, 
        Watir::Exception::ObjectReadOnlyException
        return false
      end
      return false if ! document.iscontentEditable 
      # Now iterate up the DOM element tree and return false if any
      # parent element isn't visible or is disabled
      object = document
      while object
        begin
          if object.style.invoke('visibility') =~ /^hidden$/i
            return false
          end
          if object.style.invoke('display') =~ /^none$/i
            return false
          end
          if object.invoke('isDisabled')
            return false
          end
        rescue WIN32OLERuntimeError
        end
        object += '.parentElement'
      end
      true
    end
    # for watir element returns array of arrays where each element is a [name, value] as long as value is other than null or blank
    def get_attributes
      attrs = []
      self.document.attributes.each do |atr|
        k= []
        next if (atr.value == 'null') || (atr.value == '')
        k << atr.name << atr.value
        attrs << k
      end
      return attrs.sort
    end
    def attribute_value(attribute_name)
      assert_exists
      return ole_object.getAttribute(attribute_name)
    end
  end
end
## class Watir::IE
class Watir::Browser
  include AdifyFileFunctions
  ## 20141030 AA start=============
   def wait_until_ready(how, what, desc = '', timeout = 45)
      msg = "wait_until_ready: element: #{how}=#{what}"
      msg << " #{desc}" if desc.length > 0
      proc_exists  = Proc.new { self.element(how, what).exists? }
      proc_enabled = Proc.new { self.element(how, what).visible? }
      case element
      when :link
        proc_exists  = Proc.new { self.link(how, what).exists? }
        proc_enabled = Proc.new { self.link(how, what).visible?}
      when :div
        proc_exists  = Proc.new { self.div(how, what).exists? }
        proc_enabled = Proc.new { self.div(how, what).visible?}
      end
      start = ::Time.now.to_f
      if Watir::Wait.until(timeout) { proc_exists.call }
        if Watir::Wait.until(timeout) { proc_enabled.call }
          stop = ::Time.now.to_f
          ## $logger.info("#{__method__}: start:#{"%.5f" % start} stop:#{"%.5f" % stop}")
          $logger.info("#{__method__} #{msg} (#{"%.5f" % (stop - start)} seconds)")
          true
        else
          $logger.info(msg)
        end
      else
        $logger.info(msg)
      end
    rescue
      $logger.info("Unable to #{msg}. '#{$!}'")
    end
    def select_site_for_proposal(target_site_url)
      $logger.info("Selecting all rows with site url #{target_site_url}")
      ## tabl_2 = div(:id => "ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_dtInventory").table(:index => 1)
      tabl_2 = div(:id => "ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_dtInventory").tables[1]
      for i in  0..tabl_2.trs.length - 2
        tabl_2[i].checkbox.set if  tabl_2[i].text.include?(target_site_url.strip) ## (tabl_2[i].tds.length > 0) && 
      end
    end
    def fill_in_flight_dialog(line_item)
      $logger.info("Filling in local flight info for line item <#{line_item.name}>")
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_NewFlightDialog_NewFlightName").set line_item.name
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_NewFlightDialog_NewFlightStartDate_dateinput").set line_item.start_date
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_NewFlightDialog_NewFlightEndDate_dateinput").set line_item.end_date
      link(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_NewFlightDialog_Save").click
    end
    def get_available_values_for_proposal_193(proposal, net_builder)
      $logger.info("Getting available data for the proposal <#{proposal.name}> - ruby 1.9.3")
      proposal.sales_manager = NetworkUser.new(net_builder,{:first_name => self.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlSalesMgr").options[2].text.split(',')[1].strip ,:last_name => self.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlSalesMgr").options[2].text.split(',')[0].strip})
      proposal.account_manager = NetworkUser.new(net_builder,{:first_name => self.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlAcctmgr").options[2].text.split(',')[1].strip,:last_name => self.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlAcctmgr").options[2].text.split(',')[0].strip})
      proposal.campaign_manager = NetworkUser.new(net_builder,{:first_name => self.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlCampMgr").options[2].text.split(',')[1].strip,:last_name => self.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlCampMgr").options[2].text.split(',')[0].strip})
      proposal.sales_rep1 = NetworkUser.new(net_builder,{:first_name => self.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlSalesRep1").options[2].text.split(',')[1].strip,:last_name => self.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlSalesRep1").options[2].text.split(',')[0].strip})
      proposal.sales_rep2 = NetworkUser.new(net_builder,{:first_name => self.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlSalesRep2").options[2].text.split(',')[1].strip,:last_name => self.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlSalesRep2").options[2].text.split(',')[0].strip})
      proposal.sales_rep3 = NetworkUser.new(net_builder,{:first_name => self.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlSalesRep3").options[2].text.split(',')[1].strip,:last_name => self.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlSalesRep3").options[2].text.split(',')[0].strip})
     end
    def get_available_values_for_proposal_187(proposal, net_builder)
      $logger.info("Getting available data for the proposal <#{proposal.name}> - ruby 1.8.7")
      proposal.sales_manager = NetworkUser.new(net_builder,{:first_name => self.select_list(:id,/#{$app.slProposalResourceddlSalesMgrId}/).options[2].split(',')[1].strip ,:last_name => self.select_list(:id,/#{$app.slProposalResourceddlSalesMgrId}/).options[2].split(',')[0].strip})
      proposal.account_manager = NetworkUser.new(net_builder,{:first_name => self.select_list(:id,/#{$app.slProposalResourceddlAcctmgrId}/).options[2].split(',')[1].strip,      :last_name => self.select_list(:id,/#{$app.slProposalResourceddlAcctmgrId}/).options[2].split(',')[0].strip})
      proposal.campaign_manager = NetworkUser.new(net_builder,{:first_name => self.select_list(:id,/#{$app.slProposalResourceddlCampMgrId}/).options[2].split(',')[1].strip,      :last_name => self.select_list(:id,/#{$app.slProposalResourceddlCampMgrId}/).options[2].split(',')[0].strip})
      proposal.sales_rep1 = NetworkUser.new(net_builder,{:first_name => self.select_list(:id,/#{$app.slProposalResourceddlSalesRep1Id}/).options[2].split(',')[1].strip,:last_name => self.select_list(:id,/#{$app.slProposalResourceddlSalesRep1Id}/).options[2].split(',')[0].strip})
      proposal.sales_rep2 = NetworkUser.new(net_builder,{:first_name => self.select_list(:id,/#{$app.slProposalResourceddlSalesRep2Id}/).options[2].split(',')[1].strip,:last_name => self.select_list(:id,/#{$app.slProposalResourceddlSalesRep2Id}/).options[2].split(',')[0].strip})
      proposal.sales_rep3 = NetworkUser.new(net_builder,{:first_name => self.select_list(:id,/#{$app.slProposalResourceddlSalesRep3Id}/).options[2].split(',')[1].strip,:last_name => self.select_list(:id,/#{$app.slProposalResourceddlSalesRep3Id}/).options[2].split(',')[0].strip})
    end
    def fill_out_proposal_details(proposal)
      $logger.info("Filling out proposal details <#{proposal.name}>")
      $logger.info("Setting proposal name <#{proposal.name}>")
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalName").set proposal.name
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_AgencyMenu").option(:text, proposal.agency).select  if self.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_AgencyMenu").options.length > 0 && self.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_AgencyMenu").option(:value, proposal.agency)
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_PaymentTermsMenu").option(:text,proposal.payment_terms).select  if self.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_PaymentTermsMenu").options.length > 0 && self.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_PaymentTermsMenu").option(:value, proposal.payment_terms)
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_AdvertiserMenu").option(:text,self.select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_AdvertiserMenu").options[1].text.to_s).select if RUBY_VERSION != "1.8.7"
     # link(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_EditCategoryButton").click
      #select_category(['Automotive'])
     #select_category
     ## ie.select_list(:id,/#{$app.slAdvertiserMenuId}/).option(:text,/#{@proposal.advertiser_name}/).select  if ie.select_list(:id,/#{$app.slAdvertiserMenuId}/).option(:text,/#{proposal.advertiser_name}/).exists?
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlSalesMgr").option(:text,proposal.sales_manager.last_name+", "+proposal.sales_manager.first_name).select
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlAcctmgr").option(:text,proposal.account_manager.last_name+", "+proposal.account_manager.first_name).select
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlCampMgr").option(:text,proposal.campaign_manager.last_name+", "+proposal.campaign_manager.first_name).select
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlSalesRep1").option(:text,proposal.sales_rep1.last_name+", "+proposal.sales_rep1.first_name).select
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlSalesRep2").option(:text,proposal.sales_rep2.last_name+", "+proposal.sales_rep2.first_name).select
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlSalesRep3").option(:text,proposal.sales_rep3.last_name+", "+proposal.sales_rep3.first_name).select
      if link(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_SuccessMetric_updatePrimaryGoalButton")
        link(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_SuccessMetric_updatePrimaryGoalButton").click
        sleep 3
        link(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_SuccessMetric_SuccessMetricDialog_Save").click
        sleep 3
      end
    end
   def fill_out_proposal_details_fast(proposal)
      $logger.info("Filling out proposal details <#{proposal.name}>")
      $logger.info("Setting proposal name <#{proposal.name}>")
      sleep 2 
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalName").set proposal.name
      $logger.info("Setting proposal agency")
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_AgencyMenu").options[2].select  
      $logger.info("Setting proposal payment terms")
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_PaymentTermsMenu").options[2].select
      $logger.info("Setting proposal agency")
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_AdvertiserName").set "_CVS"    ##  modified by vlad
#      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_AgencyMenu").options[0]
#      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_hdnAdvertiserId").options[1].select 
     # select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_AdvertiserMenu").options[2].select 
     $logger.info("Setting proposal category")
     link(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_EditCategoryButton").click
     ## select_category(['Automotive'])    
     select_category   ##  vlad modified select_category
     ## ie.select_list(:id,/#{$app.slAdvertiserMenuId}/).option(:text,/#{@proposal.advertiser_name}/).select  if ie.select_list(:id,/#{$app.slAdvertiserMenuId}/).option(:text,/#{proposal.advertiser_name}/).exists?  ##  vlad  
      $logger.info("Setting proposal sales manager")
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlSalesMgr").options[2].select
      $logger.info("Setting proposal account manager")
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlAcctmgr").options[2].select
      $logger.info("Setting proposal campaign manager")
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlCampMgr").options[2].select
      $logger.info("Setting proposal sales rep 1")
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlSalesRep1").options[2].select
      $logger.info("Setting proposal sales rep 2") 
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlSalesRep2").options[2].select
 #     $logger.info("Setting proposal sales rep 3")
 #     select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_ProposalResource_ddlSalesRep3").options[2].select
       $logger.info("Setting proposal success metric")
      if link(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_SuccessMetric_updatePrimaryGoalButton")
        link(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_SuccessMetric_updatePrimaryGoalButton").click
        sleep 3
        $logger.info("Saving proposal success metric")
        link(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_SuccessMetric_SuccessMetricDialog_Save").click
        sleep 3
      end
    end    
    def set_site_search_criteria(site)
      ## === Jeff  TO DO: select search criteria.
      ## tbl = ie.table(:id,/tblDimensions/)
      ## row = tbl.rows
      ## row[1][0].link(:href,/#/).click
      ## ========================================
 #     link(:text,"Site URL").click
 #     sleep 2
 #     text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_txtSearchMembersFromServer").set site.url
 #     sleep 1
 #     link(:text,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_btnSearchMembersServer").click
 #     sleep 3
 #     checkbox(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_divCheckBoxLists").set
      
      return true
    end
    def adhoc_dialog_fill_out_old(li)
      $logger.info("Filling out AdHoc line item details <#{li.name}>")
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemItemType").option(:value,li.item_type).select
      sleep 1
      checkbox(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemSyncToConsole").set
      sleep 1
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemName").set li.name
      ## select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemOwnerReach").option(:text, li.li_owner).select
      ### select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemOwnerReach").option(:text,"testpub123")
      ### sleep 3
      li.url = select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemOwnerReach").options[1].text ## if AdifyTest.ruby_version >= 190
   ##   select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemURLReach").option(:text,li.url).select
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemOwnerReach").option(:text,li.url).select
      sleep 1
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemURLReach").options[1].select
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemAdHocSection").option(:text,li.category_value_id).select
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemAdHocMediaType").option(:text, li.media_type).select
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemAdServer").option(:text, li.ad_server_type).select
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemAdHocEmail").set li.owner_email
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemStartDate_dateinput").set li.start_date
      text_field(:id, "ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemEndDate_dateinput").set li.end_date
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemAdSize").option(:text, "300x250").select
  #    select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemAdSize").select_value("1608")
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemPlacement").option(:text, li.placement_type).select
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemCostModel").option(:text, li.cost_model).select
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_BulkEditDialog_BulkEditUnitCost").set li.unit_cost
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_BulkEditDialog_BulkEditUnits").set li.item_number
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_BulkEditDialog_BulkEditCommission").set li.comissions
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemComment").set li.comment
      sleep 1
      link(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_Save").click
      sleep 15
    end
        def adhoc_dialog_fill_out(li)
      $logger.info("Filling out AdHoc line item details <#{li.name}>")
 #     checkbox(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_ProposalItemTable_js_CheckState_cb_-2137483650").set
      tabl_2 = div(:id =>"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_ProposalItemTable").table(:index => 1)
      for i in  0..tabl_2.trs.length - 2
        sleep 0
        tabl_2[i].checkbox.set if  tabl_2[i].text.include?("AH") ## (tabl_2[i].tds.length > 0) && 
        sleep 0
      end

      button(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_ButtonAction").click    
      sleep 2        
      ##  select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemItemType").option(:value,li.item_type).select    ##  vlad
      sleep 1
#      checkbox(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemSyncToConsole").set
      sleep 1
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemName").set li.name
      ## select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemOwnerReach").option(:text, li.li_owner).select
      ### select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemOwnerReach").option(:text,"testpub123")
      ### sleep 3
      li.url = select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemOwnerReach").options[1].text ## if AdifyTest.ruby_version >= 190
   ##   select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemURLReach").option(:text,li.url).select
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemOwnerReach").option(:text,li.url).select
      sleep 1
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemURLReach").options[1].select
#      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemAdHocSection").option(:text,li.category_value_id).select
#      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemAdHocMediaType").option(:text, li.media_type).select
#      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemAdServer").option(:text, li.ad_server_type).select
#      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemAdHocEmail").set li.owner_email
#      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemStartDate_dateinput").set li.start_date
#      text_field(:id, "ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemEndDate_dateinput").set li.end_date
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemAdSize").option(:text, "300x250").select
  #    select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemAdSize").select_value("1608")
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemPlacement").option(:text, li.placement_type).select
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemCostModel").option(:text, li.cost_model).select
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_BulkEditDialog_BulkEditUnitCost").set li.unit_cost
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_BulkEditDialog_BulkEditUnits").set li.item_number
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_BulkEditDialog_BulkEditCommission").set li.comissions
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_NewItemComment").set li.comment
      sleep 1
      link(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_NewItemDialog_Save").click
      sleep 15
    end
    def check_lines_for_flight_bulk_edit(li)
      sleep 4
      $logger.info("check_lines_for_flight_bulk_edit: finding and checking checkboxes for line item to bulk edit it li: <#{li.name}>")
      unless div(:id =>"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_ProposalItemTable").table(:index => 1)
        $logger.info("Table no longer embedded!")
      end
      tabl_2 = div(:id =>"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_ProposalItemTable").table(:index => 1)
      for i in  0..tabl_2.trs.length - 2
        sleep 0
        tabl_2[i].checkbox.set if  tabl_2[i].text.include?(li.name.strip) ## (tabl_2[i].tds.length > 0) && 
        sleep 0
      end
      sleep 0
    end
    def bulk_edit_selected_dialog_fill_out(li)
   #   Watir::Wait.until { execute_script("return jQuery.active") == 0 }
      sleep 6
      $logger.info("Starting filling in bulk edit dialog")
      select_list(:id, "ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_BulkEditDialog_BulkEditPlacement").option(:text,li.placement_type).select
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_BulkEditDialog_BulkEditCostModel").option(:text,li.cost_model).select
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_BulkEditDialog_BulkEditStartDate_dateinput").set li.start_date
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_BulkEditDialog_BulkEditEndDate_dateinput").set li.end_date
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_BulkEditDialog_BulkEditUnitCost").set li.unit_cost
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_BulkEditDialog_BulkEditUnits").set li.item_number
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_BulkEditDialog_BulkEditCommission").set li.comissions
      link(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalOrder_TabSet_ProposalEditor_BulkEditDialog_Update").click
      $logger.info("Finished filling in bulk edit dialog")
      sleep 6
    end
    def approve_proposal_fast
      sleep 5
      $logger.info("approval process: <#{$0}>")
      div(:id=>"ctl00_ctl00_BodyContent_BodyContent_TabSet").link(:text, "Approvals").click
      sleep 3
      input(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalApprovals_btnApproveProposal").click
      sleep 3
      link(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalApprovals_MgrApproveDialog_MgrApprove").click
      $logger.info("Proposal has been pre-approved. <#{$0}>")
      sleep 20
    end
    def fill_out_local_site(site)
      select_list(:id,/BodyContent_ddlInventoryType/).option(:text,/Local/).select
      sleep 3
      radio(:id,/rdMediaType_3/).set    ## aa have to work out setting this control by text next to radio button radio(:label,/#{site.mediaout_outlet}/).set
      table(:id,/dualLBState/).select_list(:id, /BodyContent/).option(:text,/#{site.available_states}/).select
      owner_for_drop_down_list = site.publisher.name + site.publisher.lastName 
      ## select_list(:id,/ddlSiteOwners/).option(:text,/#{site.publisher.name}/).select
#      select_list(:id,/ddlSiteOwners/).option(:text,/#{owner_for_drop_down_list}/).select
      link(:id, /selectOwnerButton/).click
      sleep 1 ## vvv
      text_field(:id,/selectOwnerSearchText/).set owner_for_drop_down_list
      input(:id, /selectOwnerSearchButton/).click
      sleep 2
 #     radio(:id, /rb_/).set  
      radio(:name,/OwnerDataTable/).set
      sleep 1
      link(:id, /SelectOwnerDialog_OK/).click
      select_list(:id,/ddlSitePayees/).option(:text,/#{owner_for_drop_down_list}/).select
    end
    def select_partner_network(net_id)
      text_field(:id,/campaignDescription/).set "SmokeTest proposal t description"
      sleep 2  * GlobalAdjustedSleepTime
      link(:id, /#{$app.linkPartnerNetsBtnId}/).click
      sleep 20  * GlobalAdjustedSleepTime
      text_field(:id,/#{$app.tSearchDialogId}/).set net_id
      button(:id,/#{$app.btnSearchDialogId}/).click
      sleep 3  * GlobalAdjustedSleepTime
      checkbox(:id,/#{$app.cbSelectNetId}/).set if checkbox(:id,/#{$app.cbSelectNetId}/).exists?
      $logger.info("Fail to find partner network #{net_name}") unless checkbox(:id,/#{$app.cbSelectNetId}/).exists?
      link(:id,/#{$app.linkOkDialogCampBtnId}/).click          if     link(:id,/#{$app.linkOkDialogCampBtnId}/).exists?
    end

  
  ### 20141030 AA end============================================================================
  def self.set_env_name(env)
    @@env = env
  end
  ### ============================================================================
  def self.goto_with_cookie(file_location="", cookie = nil)
    ## self.close
    Watir::IE.update_cookie("afy11", cookie) if cookie
    Watir::IE.delete_cookie("afy11") unless cookie
    sleep 2
    return  Watir::IE.start file_location
  end
  ### ============================================================================
  def self.delete_cookie(domain = "afy11")
    cookie_location = get_special_folder_location(COOKIES)
    Dir.foreach(cookie_location){|file_name|  # find cookie file in OS
      if file_name.afy11_cookie_file?       #      if (file  =~/#{domain}/) --before microsoft security patch
        puts "Script is about to delete #{cookie_location}\\#{file_name} "
        File.delete(cookie_location + "\\" + file_name)
      end
    }
  end
  ### ============================================================================
  def self.update_cookie(domain = "afy11", new_cookie = 'a=sI+O2cpX80aojrSO1TOcKw; c=')
    cookie_location = get_special_folder_location(COOKIES)
    Dir.foreach(cookie_location) do |file|  # find cookie file in OS
      if file.afy11_cookie_file? #      if (file  =~/#{domain}/) --before microsoft security patch
        cookieFile = File.open(cookie_location + "\\" + file,  "rb+")
        cookieFile.pos = 2
        cookieFile.write(new_cookie[2,22])   # re-write a cookie for BT
        cookieFile.close
        return true
      end
    end
  end
  ### ============================================================================
  def  self.get_special_folder_location(spec_folder_name)
    shell = WIN32OLE.new('Shell.Application')
    folder = shell.Namespace(spec_folder_name)
    folder_item = folder.Self
    return folder_item.Path
  end
  ### ============================================================================
  def rescue_wait_retry(exception = Watir::Exception::UnknownObjectException, times = 10, seconds = 2, &block)
    begin
      return yield
    rescue => e
      puts "Caught #{exception}: #{e}. Sleeping #{seconds} seconds." if $DEBUG
      sleep(seconds*GlobalAdjustedSleepTime)
      @ie.wait
      if (times -= 1)> 0
        puts "Retrying... #{times} times left" if $DEBUG
        retry
      end
    end
    yield
  end  
  ### ============================================================================
  def login(uid,pwd)
    ##    maximize
    goto($app.url)
    $logger.info("Script is about to login to #{$app.name} page user: <#{uid}> password: <#{pwd}>")
    sign_out
    text_field(:id,/#{$app.uid_textField_id}/).set uid 
    text_field(:id,/#{$app.pwd_textfield_id}/).set pwd.to_s
    button(:id,/#{$app.signIn_button_id}/, 9200).click
    ## link(:id,/#{$app.signIn_button_id}/, 9200).click
    $app = HomePage.new
    sleep 1
  end
  ### ============================================================================
  def sign_out
    link(:id,/#{$app.linkSignOutId}/).click if link(:id,/#{$app.linkSignOutId}/).exist?
  end
  ### ============================================================================
  def go_campaign_editor(campaign)
    $logger.info "Navigating to the campaign editor for <#{campaign.name}>"
    # Click on the Sales tab
    link(:href,/#{$app.linkSalesHref}/, 3101).click if $app.kind_of?NetworkCS
    return $logger.info "Wrong Page act: </#{$app.name}> exp:<SalesTab> /"  unless $app.kind_of?SalesTab
    link(:id,/#{$app.linkCampaignsId}/, 3101).click 
    link(:text, /#{campaign.name}/,(campaign.type.downcase == "standard" ? 3102 : 3110)).click
    
    # Set our page object
    $app = (campaign.type.downcase == "standard" ? CreateCampaign.new : CreateExtCampaign.new)
    sleep 1 * GlobalAdjustedSleepTime
  end
  ### ============================================================================
  def go_line_items_tab
    $logger.info "Navigating to the Line Items tab"
    go_campaign_editor unless $app.kind_of?CreateCampaign
    div(:id,/#{$app.divClientTabViewId}/).link(:text,/#{$app.linkLineItemsBtnItext}/).click
    $app = LineItemPage.new
  end
  ### ============================================================================
  def copy_line_item(buy, copied_buy_name = 'COPY')
    $logger.info "Copying <#{buy.name}>"
    my_original_row = find_row(get_table_from_div($app.divLineItemTblId), 'Line item', buy.name)
    my_original_row.checkboxes[0].set(true)
    link(:text, /#{$app.linkCopyBtnItext}/).click
    sleep 2 * GlobalAdjustedSleepTime
    my_table = get_table_from_div($app.divLineItemTblId)
    my_copied_row = find_row(my_table, 'Line item', buy.name + ' - ')
    dialog_text_field_set(my_copied_row[my_table.row_values(1).index('Line item')+1], copied_buy_name)
    div(:id,/saveButtonsContainer/).link(:id,/#{$app.linkSaveBtnId}/).click
    $app = SalesTab.new
  end
  ### ============================================================================
  def delete_line_items(*buys)
    $logger.info "Deleting <#{buys.length}> buy(s)"
    buys.each do |buy|
      myRow = find_row(get_table_from_div($app.divLineItemTblId), 'Line item', buy.name)
      myRow.checkboxes[0].set(true)
    end
    link(:text, /#{$app.linkDeleteBtnItext}/).click
    sleep 1  * GlobalAdjustedSleepTime
    div(:id,/saveButtonsContainer/).link(:id,/#{$app.linkSaveBtnId}/).click
    sleep 2  * GlobalAdjustedSleepTime
    $app = SalesTab.new
  end
  ### ============================================================================
  def go_site_payouts(buy)
    $logger.info "Navigating to Edit Site Payouts for <#{buy.name}>"
    go_line_items_tab unless $app.kind_of?LineItemPage       # Make sure we're on the line items page
    @table_lines = get_table_from_div($app.divLineItemTblId)
    my_row = find_row(@table_lines, 'Line item', buy.name)
    my_row.cell(:class,/SiteActions/).links[0].click
    link(:text,"Edit site payouts").click
    sleep 4  * GlobalAdjustedSleepTime
    $app = EditSitePayoutsPage.new
  end
  ### ============================================================================
  def scrub_site_payouts
    $logger.info 'Scrubing site payout info'
    return unless $app.kind_of?EditSitePayoutsPage
    # Make sure we have the results for all sites
    table(:id, /#{$app.tSearchTypeId}/).radio(:value, 'Site').set
    button(:id, /#{$app.btnSearchButtonId}/).click
    sleep 1  * GlobalAdjustedSleepTime
    # Get the table data
    my_table_body = div(:id, /#{$app.divSearchResultsId}/).table(:index, 1).body(:index, 1)
    my_payout_info = { }
    my_table_body.each do |row|
      my_payout_info[row[1].to_s] = { :payoutType => row[6].to_s, :payout => row[7].to_s }
    end
    return my_payout_info
  end
  ### ============================================================================
  def link_click(id_value,nextPageID)
    link(:id, id_value).click
    $logger.info "Link id #{id_value} has been clicked.<#{$app.name}>"
    unless nextPageID == 0
      $app.navigate nextPageID
    end
  end
  ### ============================================================================
  def dialog_select_list_set(table_cell,value_to_set, msg_for_log = "")
    $logger.info("Assigning property: <#{msg_for_log}> value: <#{value_to_set}>", value_to_set != "")
    @tc = table_cell
    sleep 2  * GlobalAdjustedSleepTime
    return "Empty value to set" if value_to_set == ""
 ##   begin ## Set Click Location
      @tc.click
      sleep 2  * GlobalAdjustedSleepTime
      dv = get_active_div_by_pattern('dropdownceditor') until dv
     ## option = dv.select_lists[0].getAllContents.find{|item|
    # option = dv.select_lists[0].options.find{|item|
    #    item.text.gsub(" ","").include?(value_to_set.gsub(" ",""))
    #  }
      dv.select_lists[0].options.each{|o|
       (dv.select_lists[0].select(o); break) if (o.kind_of?String) && (o.gsub(" ","") =~ /#{value_to_set.gsub(" ","")}/)                  ## for ruby >~ 1.8.6
       (dv.select_lists[0].select_value(o.value); break) if (o.kind_of?Watir::Option) && (o.text.gsub(" ","") =~ /#{value_to_set.gsub(" ","")}/)    ## for ruby >~ 1.9.2
      }
     ## dv.select_lists[0].select_value @option
      if dv.button(:text,"Save").exists?
        dv.button(:text,"Save").click
      elsif dv.button(:text,"OK").exists?
        dv.button(:text,"OK").click
      end  
      sleep 1  * GlobalAdjustedSleepTime
   ## end until (@tc.to_s.gsub(" ","").strip.downcase.include?value_to_set.gsub(" ","").downcase.strip)
 ##  end until (@tc.text.to_s.gsub(" ","").strip.downcase.include?value_to_set.gsub(" ","").downcase.strip)
  end  
  ### =============================================================================
  def dialog_text_field_set(table_cell,value_to_set,msg_for_log = "")
    $logger.info("Assigning property: <#{msg_for_log}> value: <#{value_to_set}>", value_to_set != "")
    return if value_to_set == ""
    sleep 1  * GlobalAdjustedSleepTime
    @tc = table_cell
  #  begin ## Set Description
      @tc.click
      sleep 1  * GlobalAdjustedSleepTime
      dv = get_active_div_by_pattern('textboxceditor') ## if get_active_div_by_pattern('textboxceditor')  != 0
      dv.text_fields[0].set(value_to_set)
      if dv.button(:text,"Save").exists?
        dv.button(:text,"Save").click
      elsif dv.button(:text,"OK").exists?
        dv.button(:text,"OK").click
      end
      sleep 1  * GlobalAdjustedSleepTime
   ## end until @tc.to_s.gsub(/[., ]/,"").downcase.strip.include?value_to_set.gsub(/[., ]/,"").downcase.strip
   # end until @tc.text.to_s.gsub(/[., ]/,"").downcase.strip.include?value_to_set.gsub(/[., ]/,"").downcase.strip
  end
  ### =============================================================================
  def dialog_text_area_set(table_cell,value_to_set,msg_for_log = "")
    $logger.info("Assigning property: <#{msg_for_log}> value: <#{value_to_set}>", value_to_set != "")
    return if value_to_set == ""
    sleep 1  * GlobalAdjustedSleepTime
    @tc = table_cell
    begin ## Set Description
      @tc.click
      sleep 4  * GlobalAdjustedSleepTime
      dv = get_active_div_by_pattern('textareaceditor')
      dv.text_fields[0].set(value_to_set)
      if dv.button(:text,"Save").exists?
        dv.button(:text,"Save").click
      elsif dv.button(:text,"OK").exists?
        dv.button(:text,"OK").click
      end  
      sleep 1  * GlobalAdjustedSleepTime
   ## end until @tc.to_s.gsub(/[., ]/,"").downcase.strip.include?value_to_set.gsub(/[., ]/,"").downcase.strip
  ## end while @tc.to_s.empty?
   end while @tc.text.to_s.empty?
  end
  ### =============================================================================
  def dialog_date_field_set(table_cell,value_to_set,msg_for_log = "")
    $logger.info("Assigning property: <#{msg_for_log}> value: <#{value_to_set}>", value_to_set != "")
    return if value_to_set == ""
    sleep 2  * GlobalAdjustedSleepTime
    table_cell.click
    sleep 2  * GlobalAdjustedSleepTime
    dv = get_active_div_by_pattern('datetextceditor')
    dv.text_fields[0].set(value_to_set)
    dv.button(:text,'OK').click
    sleep 1  * GlobalAdjustedSleepTime
  end
  ### =============================================================================
  def link(*arg)
    sleep 1  * GlobalAdjustedSleepTime
    if arg.size == 2
      how,what = arg
    else
      how,what,page = arg
      $logger.info "Link id #{what} has been clicked <#{$app.name}>"
      unless page == 0
        $app.navigate page
      end
    end 
    rescue_wait_retry { super(how,what) }
  end
    ### =============================================================================
  def text_field(*arg)
    sleep 1  * GlobalAdjustedSleepTime
    if arg.size == 2
      how,what = arg
    elsif arg.size == 1
      how = arg
    else
      how,what,page = arg
      $logger.info "Link id #{what} has been clicked <#{$app.name}>"
      unless page == 0
        $app.navigate page
      end
    end 
    rescue_wait_retry { super(how,what) }
  end
      ### =============================================================================
  def select_list(*arg)
    sleep 1  * GlobalAdjustedSleepTime
    if arg.size == 2
      how,what = arg
    else
      how,what,page = arg
      $logger.info "Link id #{what} has been clicked <#{$app.name}>"
      unless page == 0
        $app.navigate page
      end
    end 
    rescue_wait_retry { super(how,what) }
  end

  ### =============================================================================
  def button(*arg)
    sleep 1  * GlobalAdjustedSleepTime
    if arg.size == 2
      how,what = arg
    else
      how,what,page = arg
      $logger.info "Button id #{what} has been clicked <#{$app.name}>"
      unless page == 0
        $app.navigate page
      end
    end 
    rescue_wait_retry { super(how,what) }
  end
  ### =============================================================================
#  def table(how,what)
#    rescue_wait_retry {super(how,what)}
#  end
#  ### =============================================================================
#  def div(how,what)
#    rescue_wait_retry {super(how,what)}
#  end
  ### =============================================================================
  def fill_out_nb_account(aNBAccount)
    if $app.page_id == 9401
      select_list(:id,/#{$app.slCountryID}/).select aNBAccount.country
      text_field(:id,/#{$app.tUseridID}/).set aNBAccount.name
      text_field(:id,/#{$app.tPasswordID}/).set aNBAccount.password
      text_field(:id,/#{$app.tConfirmPass}/).set aNBAccount.confirmPass
      text_field(:id,/#{$app.tFirstN}/).set aNBAccount.firstN
      text_field(:id,/#{$app.tLastN}/).set aNBAccount.lastN
      text_field(:id,/#{$app.tCompanyN}/).set aNBAccount.companyN
      text_field(:id,/#{$app.tAddress1}/).set aNBAccount.address1
      text_field(:id,/#{$app.tAddress2}/).set aNBAccount.address2
      text_field(:id,/#{$app.tCity}/).set aNBAccount.city
      text_field(:id,/#{$app.tPostalCodeCa}/).set aNBAccount.zip
      text_field(:id,/#{$app.tEmail}/).set aNBAccount.email
      text_field(:id,/#{$app.tPhoneN}/).set aNBAccount.phoneN
      if aNBAccount.country == 'United States'
        select_list(:id,/#{$app.slState}/).select aNBAccount.state
      elsif aNBAccount.country == 'Canada'
        select_list(:id,/#{$app.slProvinceCa}/).select aNBAccount.province
      elsif aNBAccount.country == 'Japan'
        select_list(:id,/#{$app.slPrefecture}/).select aNBAccount.prefecture
      elsif aNBAccount.country == 'Australia'
        text_field(:id,/#{$app.tRegion}/).set aNBAccount.region
      elsif aNBAccount.country == 'United Kingdom'  
        select_list(:id,/#{$app.slCounty}/).select aNBAccount.county
      end
      $logger.info "Accoun page is filled out NB primery name = #{aNBAccount.name}"
    else 
      $logger.info "Unexpected page id <#{$app.page_id}> expected id is 9401." 
    end
  end
  ### =============================================================================
  def getSpanValue(spanId)
    id = 0 
    if span(:id,/#{spanId}/).exists?
      id = span(:id,/#{spanId}/).text
      $logger.info "Span id<#{spanId}>  InnerText is #{id}"
    else
      $logger.error "Span id<#{spanId}> is not found"
    end 
    return id 
  end
  ### =============================================================================
  def fill_out_NetDetails(aNBAccount)
    if $app.page_id == 9403
      text_field(:id,/#{$app.tNetworkName}/).set aNBAccount.networkName
      text_field(:id,/#{$app.tDescription}/).set aNBAccount.description
      text_field(:id,/#{$app.tNetworkURL}/).set aNBAccount.networkURL
      text_field(:id,/#{$app.tNetworkContact}/).set aNBAccount.networkContact
      text_field(:id,/#{$app.tContactEmail}/).set aNBAccount.contactEmail
      $logger.info "Network set up page is filled out New network name = #{aNBAccount.networkName}"
    else
      $logger.info "Unexpected page id <#{$app.page_id}> expected id is 9403." 
    end
  end
  ### =============================================================================
  def fill_out_pubAccount(pubAccount)
    if $app.page_id == 8200 
 #     select_list(:id,/#{$app.slCountryId}/).select pubAccount.country
      select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_CountryDropDownList").option(:text, pubAccount.country).select
#      text_field(:id,/#{$app.tUserIDId}/).set pubAccount.name
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_UserNameTextBox").set pubAccount.name
#      text_field(:id,/#{$app.tFirstNameId}/).set pubAccount.firstName
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_FirstNameTextBox").set pubAccount.name
#      if (text_field(:id,/#{$app.tCompanyNameId}/).exists?)
#        text_field(:id,/#{$app.tCompanyNameId}/).set pubAccount.companyName
#      end
       if (text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_PublisherAccountNameTextBox").exists?)
        text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_PublisherAccountNameTextBox").set(pubAccount.name + pubAccount.lastName)
      end     
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_LastNameTextBox").set pubAccount.lastName
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_Address1TextBox").set pubAccount.address1
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_Address2TextBox").set pubAccount.address2
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_CityTextBox").set pubAccount.city
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_PostalCodeTextBox").set pubAccount.zip
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_AgencyEmailAddressTextBox").set pubAccount.email
      text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_PhoneNumberTextBox").set pubAccount.phoneNumber
      ##==============  Added by Vlad ================
      #if radio(:id, "ctl00_ctl00_BodyContent_BodyContent_InventoryTypeList_1").exists?
       #  radio(:id, "ctl00_ctl00_BodyContent_BodyContent_InventoryTypeList_1").set
        # $logger.info "New radio buttons Inventory Bucket exist"
      #else
       #  $logger.info "New radio buttons Inventory Bucket do not exist"   
      #end  
      if checkbox(:id, "ctl00_ctl00_BodyContent_BodyContent_InventoryTypeList_1").exists?
         $logger.info "New check boxes Inventory Bucket exist"
         checkbox(:id, "ctl00_ctl00_BodyContent_BodyContent_InventoryTypeList_1").set
       else
         $logger.info "New check boxes Inventory Bucket do not exist"   
      end 
      ##===============================================
      if pubAccount.country == 'United States'
        select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_StateDropDownList").select pubAccount.state
      elsif pubAccount.country == 'Canada'
        select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_ProvinceDropDownList").select pubAccount.province
      elsif pubAccount.country == 'Japan'
        select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_PrefectureDropDownList").select pubAccount.prefecture
      elsif pubAccount.country == 'Australia'
        text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_RegionTextBox").set pubAccount.region
      elsif pubAccount.country == 'United Kingdom'  
        select_list(:id,"ctl00_ctl00_BodyContent_BodyContent_CountyDropDownList").select pubAccount.county
      end
      $logger.info "Create pub page is filled out New publisher's name = <#{pubAccount.name}>"
    else
      $logger.info "Unexpected page id <#{$app.page_id}> expected id is 2102." 
    end  
  end
  ### =============================================================================
  def fill_out_create_site (site)  ## Internal Exchange
      sleep 3  * GlobalAdjustedSleepTime
     # text_field(:id,/siteNameValue/).set site.name
     # text_field(:id,/siteURLValue/).set site.url
      ## text_field(:id,/#{$app.trssURLId}/).set site.rssURL if (text_field(:id,/#{$app.trssURLId}/).exists?) and (site.rssURL.length > 0)
     # text_field(:id,/siteDescriptionValue/).set site.description
      select_list(:id,/impressionsServed/).select site.impresPerMonth
      select_list(:id,/audienceGender/).select site.gender
      select_list(:id,/audienceAge/).select site.age
      select_list(:id,/audienceIncome/).select site.householdIncome
      select_list(:id,/ddlCategory1/).select('Automotive')
      sleep 1 * GlobalAdjustedSleepTime
      select_list(:id,/ddlSubcategory1/).select('Motorcycles')
      $logger.info "Create site page is filled out Site name = #{site.name}"

  end
  ### =============================================================================
  def fill_out_create_site_new (site)
    if ($app.page_id == 2103) or ($app.page_id == 104)
      sleep 3  * GlobalAdjustedSleepTime
      text_field(:id,/#{$app.tsiteNameId}/).set site.name
      text_field(:id,/#{$app.tsiteURLId}/).set site.url
      text_field(:id,/#{$app.trssURLId}/).set site.rssURL if (text_field(:id,/#{$app.trssURLId}/).exists?) and (site.rssURL.length > 0)
      text_field(:id,/#{$app.tsiteDescriptionId}/).set site.description
      $logger.info "Create site page is filled out Site name = #{site.name}"
    else
      $logger.info "Unexpected page id <#{$app.page_id}> expected id is 2103."
    end
  end
  #### =============================================================================
  def select_category  ## vlad modified
      sleep 0.5  * GlobalAdjustedSleepTime
      ## select_list(:id, "ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_CategoryDialog_OptimizationCategoryDialog_DropDownList1").select categories[0]
      ## link(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_EditCategoryButton").click
      select_list(:id, "ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_CategoryDialog_OptimizationCategoryDialog_DropDownList1").option(:text => "Automotive").when_present.select   ##  vlad
      sleep 0.5  * GlobalAdjustedSleepTime
    ##  link(:id,/OptimizationCategoryDialog_Save/).click   ## vlad removed RegEx
      link(:id,"ctl00_ctl00_BodyContent_BodyContent_TabSet_ProposalDetails_CategoryDialog_OptimizationCategoryDialog_Save").click
  end
  #### =============================================================================
  def fill_out_campaign(campaign)
   ($logger.info "Unexpected page id <#{$app.page_id}> expected page id is 3102."; return ) if ($app.page_id != 3102) && ($app.page_id != 3110)
    if campaign.advertiser.to_s.length == 0
      puts "adifyWatir::fill_out_campaign - needs to add steps to change advertizer"
    end
    text_field(:id,/#{$app.tPubFriendlyAdvNameId}/).set campaign.pubFriendlyAdvName
    text_field(:id,/#{$app.tCampaigNameId}/).set campaign.name
    link(:id, /#{$app.linkEditCategoryBtnId}/).click
    select_category(campaign.category)
    if campaign.type.downcase == "extended"
      select_partner_networks (campaign)
    end
   ## set_campaign_price_type(campaign)  if @@env.downcase == "staging"
    checkbox(:id, /#{$app.cbDynamicPriceId}/).set if campaign.dynamicPrice.to_s.downcase  == "true" and not(["time-based","sponsorship"].include?campaign.priceType.downcase)
    select_list(:id,/#{$app.slTimeZoneId}/).select campaign.timeZone
    checkbox(:id,/#{$app.cbInventoryId}/).set     if campaign.inventory.to_s.downcase     == "true" and not (["time-based","sponsorship"].include?campaign.priceType.downcase)
    checkbox(:id,/#{$app.cbSharedBudgetId}/).set  if campaign.sharedBudget.to_s           == "true"
    if campaign.hasAds
      campaign.ads.each do |ad|
        add_creative_to_campaign(ad)
      end
    end
    if campaign.hasConvTrafficEvents
      ## needs method to create trafficking
    end
    if campaign.dailyImpCapping.length == 2
      if select_list(:id,/#{$app.slCapMaxId}/).exists? and select_list(:id,/#{$app.slCapMaxId}/).getAllContents.include?(campaign.dailyImpCapping[0].to_s)
        select_list(:id,/#{$app.slCapMaxId}/).select campaign.dailyImpCapping[0] 
      end
      if select_list(:id,/#{$app.slCapAgeId}/).exists? and select_list(:id,/#{$app.slCapAgeId}/).getAllContents.include?(campaign.dailyImpCapping[1].to_s)
        select_list(:id,/#{$app.slCapAgeId}/).select campaign.dailyImpCapping[1]
      end  
    end
    if campaign.hasAttachments
      ## need method to create attachments
    end
    if campaign.hasCustomFields
      ## need method to create trafficking
    end
    text_field(:id,/#{$app.tSpecialInstructionsId}/).set campaign.specialInstructions
    text_field(:id,/#{$app.tCampaignTraffickingId}/).set campaign.traffickingNotes
    link(:id,/#{$app.linkSaveBtnId}/,3101).click
    ###  Jeff Add
    sleep 2 * GlobalAdjustedSleepTime
    if campaign.type.downcase == "extended" and link(:id,/NotifyNetworksDialog_Send/).exists?
      link(:id,/NotifyNetworksDialog_Send/).click 
    end
    $logger.info "Campaign's part of the page is filled out Campaign name = #{campaign.name}"
  end
  def select_partner_networks (campaign)
      text_field(:id,/campaignDescription/).set "Default ext net description"
      campaign.partnerNetworksList.each {|net|
        sleep 2  * GlobalAdjustedSleepTime
        link(:id, /#{$app.linkPartnerNetsBtnId}/).click
        sleep 8  * GlobalAdjustedSleepTime
        text_field(:id,/#{$app.tSearchDialogId}/).set net.network_Id if net and net.network_Id != ""
        text_field(:id,/#{$app.tSearchDialogId}/).set net.name       if net and net.network_Id == ""
        button(:id,/#{$app.btnSearchDialogId}/).click
        sleep 3  * GlobalAdjustedSleepTime
        checkbox(:id,/#{$app.cbSelectNetId}/).set if checkbox(:id,/#{$app.cbSelectNetId}/).exists?
        $logger.info("Fail to find partner network #{net_name}") unless checkbox(:id,/#{$app.cbSelectNetId}/).exists?
        link(:id,/#{$app.linkOkDialogCampBtnId}/).click          if     link(:id,/#{$app.linkOkDialogCampBtnId}/).exists?
      }
  end

  ### =============================================================================
  def set_campaign_price_type(campaign)
    sleep 1  * GlobalAdjustedSleepTime
    return $logger.info("Unexpected page Expected CreateCampaign") unless $app.kind_of?CreateCampaign
    tblRadioList = table(:id,/#{$app.tblPriceTypeRadioListId}/)
    rowTbl = tblRadioList.rows.find{|r| r.text.to_s.include?campaign.priceType }
    if rowTbl.radios[0].exists?
      rowTbl.radios[0].set
    else
      $logger.info("Fail to choose price type #{campaign.priceType}")
    end
    sleep 30   * GlobalAdjustedSleepTime
  end
  ### =============================================================================
  def add_creative_to_campaign(ad)
    sleep 7  * GlobalAdjustedSleepTime
    link(:id,/#{$app.linkAdsId}/,3103).click
    sleep 2 * GlobalAdjustedSleepTime
   ## link(:id,/#{$app.linkSaveDialogId}/,3103).click if link(:id,/#{$app.linkSaveDialogId}/).exists?
   ##  link(:id,/DialogContent_SaveDialog_Save_out/,3103).click if link(:id,/DialogContent_SaveDialog_Save_out/).exists?
   link(:id,"ctl00_DialogContent_SaveDialog_Save").click if link(:id,"ctl00_DialogContent_SaveDialog_Save").visible?
   sleep 20  * GlobalAdjustedSleepTime
    if ad.type.upcase.include?'HTML'
      ## refresh linkNewBannerAdBtnId
      link(:id,/#{$app.linkNewBannerAdBtnId}/).click if  link(:id,/#{$app.linkNewBannerAdBtnId}/).exists? 
      sleep 3 * GlobalAdjustedSleepTime
      link(:id,/#{$app.linkNewHtmlAdId}/,3103).click if  link(:id,/#{$app.linkNewHtmlAdId}/).exists? 
      sleep 2  * GlobalAdjustedSleepTime
      fill_out_EmptyAd(ad)
    elsif  ad.type.upcase.include?'IMAGE'
      link(:id,/#{$app.linkUploadAdsId}/,3103).click
      fill_out_EmptyAd(ad)
    else
      $logger.info "Type of the ad <#{ad.type}> is not recognized\. Ad hasn't added to the campaign"
    end
  end
  ### =============================================================================
  def create_campaign(camp)
    $logger.info "Creating campaign name <#{camp.name}>"
    ## link(:href,/#{$app.linkSalesHref}/, 3101).click if $app.kind_of?NetworkCS   ## vvv
     ##($logger.info "Wrong Page act: </#{$app.name}> exp:<SalesTab> /"; return) unless $app.kind_of?SalesTab  ## vvv
    ##link(:id, /#{$app.linkCampaignsId}/, 3101).click ## Comment vvv  ctl00_BodyContent_CreateCampaignMenuButton_CreateExtendedCampaign
    link(:id, "ctl00_BodyContent_NewBannerAd_Button").click  ## vvv
    ## link(:id,/#{$app.linkCreateStdtCampId}/, 3102).click if camp.type.downcase == "standard" ## Comment vvv
    ## link(:id,/#{$app.linkCreateExtdCampId}/, 3110).click if camp.type.downcase == "extended"  ## Comment vvv
    link(:id, "ctl00_BodyContent_CreateCampaignMenuButton_CreateExtendedCampaign").click   ## vvv
    fill_out_campaign(camp)
    sleep 5  * GlobalAdjustedSleepTime
    camp.lines.each { |line| create_line_item(line) }
##    link(:text, /#{camp.name}/,3102).click
    $app = CreateCampaign.new
    link(:id,/#{$app.linkConfirmGoLiveId}/,3104).click
    link(:id,/#{$app.linkGoLiveBtnId}/,3101).click
    sleep 2  * GlobalAdjustedSleepTime
  end
  ### =================================================================================
  def stop_all_campaigns
    return $logger.error "Unexpected page <#{$app.name}> Expected NetworkCS" unless $app.kind_of?NetworkCS
    link(:href,/#{$app.linkSalesHref}/, 3101).click
    sleep 4  * GlobalAdjustedSleepTime
    tbl = get_table_from_div($app.divCampaignTableId)
    ## row_camp = div(:id,/#{$app.divCampaignTableId}/).tables[0].rows[3] if div(:id,/#{$app.divCampaignTableId}/).tables[0].rows[3].exists?
    while tbl.rows.length > 2  ## div(:id,/#{$app.divCampaignTableId}/).tables[0].rows[3].exists?
      tbl.rows[2].cell(:class,/Actions/).link(:text,/Actions/).click if tbl.rows[2].cell(:class,/Actions/).link(:text,/Actions/).exists?
      link(:text,"Stop").click if link(:text,"Stop").exists?
      sleep 1  * GlobalAdjustedSleepTime
      tbl = get_table_from_div($app.divCampaignTableId)
    end
  end
  ### =================================================================================
  def set_conversion_tracking(campaign,action)
    $logger.info "Setting Conversion Tracking Option to: <#{action}> for campaign <#{campaign.name}>"
    link(:text, /#{campaign.name}/,3102).click
    link(:id,/#{$app.linkConverTrackingPackageId}/,3102).click
    case action.upcase
      when 'ADD NEW'
      link(:id,/#{$app.linkAddNewCtPackageId}/,3107).click
      add_new_tracking_package(campaign)
      when  'SELECT EXISTING'
      if link(:id,/#{$app.linkSelectCtPackageId}/).visible?
        link(:id,/#{$app.linkSelectCtPackageId}/,3102).click
        sleep 2  * GlobalAdjustedSleepTime
        text_field(:id,/#{$app.tSearchCtPackageId}/).set campaign.ctPackage.name
        button(:id,/#{$app.btnSearchCtPackageId}/).click
        sleep 2  * GlobalAdjustedSleepTime
        radio(:name, /#{$app.rbSelectCtPackageName}/).set
        link(:id,/#{$app.linkSaveDialogCtPackageId}/,3102).click
      end
      when  'REMOVE'
      if link(:id,/#{$app.linkRemoveCtPackageId}/).visible?
        link(:id,/#{$app.linkRemoveCtPackageId}/,3102).click
      end
      when 'GET EVENT TAGS'
      if link(:id,/#{$app.linkGetTagsCtPackageId}/).visible?
        link(:id,/#{$app.linkGetTagsCtPackageId}/,3108).click
        getConversionTags(campaign)
      end
      when  'DOWNLOAD EVENT REPORT'
      link(:id,/#{$app.linkGetReportCtPackageId}/,3102).click
    else
      $logger.info "Unexpected Conversion Tracking Options for campaign <#{campaign.name}>"
    end
    link(:id,/#{$app.linkSaveBtnId}/,3101).click
  end
  ### =================================================================================
  def add_new_tracking_package(campaign)
    $logger.info "Creating Conversion Tracking Package <#{campaign.ctPackage.name}> for campaign <#{campaign.name}>"
    text_field(:id,/#{$app.tPackageNameId}/).set campaign.ctPackage.name
    select_list(:id,/#{$app.slNumberOfEventsId}/).select campaign.ctPackage.numberOfEvents
    campaign.ctPackage.events.each_with_index do |event, index|
      event_name = '$app.tEvent'+(index+1).to_s+'ValueId'
      text_field(:id,/#{eval(event_name)}/).set event.name
      $logger.info "Added Conversion Tracking Event <#{event.name}> to Package <#{campaign.ctPackage.name}>"
    end
    if campaign.ctPackage.attributes
      link(:id,/#{$app.linkAdvancedSetUpLinkId}/,3107).click
      sleep 1  * GlobalAdjustedSleepTime
      campaign.ctPackage.attributes.each_with_index do |(attribute,value), index|
        attribute_name = '$app.tAttributeName'+(index+1).to_s+'Id'
        attribute_value= '$app.tAttributeValue'+(index+1).to_s+'Id'
        text_field(:id,/#{eval(attribute_name)}/).set attribute
        text_field(:id,/#{eval(attribute_value)}/).set value
        $logger.info "Added Conversion Tracking Attribute <#{attribute}> with Value <#{value}> to Package <#{campaign.ctPackage.name}>"
      end
    end
    link(:id,/#{$app.linkDoneButtonId}/,3102).click
    
  end
  ### =================================================================================
  def create_line_item(line)
    $logger.info "Creating line item name <#{line.name}>"
    $logger.info("Unexpected page <#{$app.name}>") unless $app.kind_of?SalesTab
    sleep 3 * GlobalAdjustedSleepTime
    begin
     ## link(:text, /#{line.campaign.name}/,3102).click
     ## div(:id,/#{$app.divClientTabViewId}/).link(:text,/#{$app.linkLineItemsBtnItext}/).click
     link(:text,"Line Items").click
     sleep 1
      $app = LineItemPage.new
      link(:id, /#{$app.linkNewBtnId}/).click
      sleep 6  * GlobalAdjustedSleepTime
      @table_lines = get_table_from_div($app.divLineItemTblId)
      @row_to_fill = find_row(@table_lines, 'Line item','Untitled')
      dialog_text_field_set(@row_to_fill.cell(:class,/Name/),line.name)
      sleep 2  * GlobalAdjustedSleepTime
      set_display_options(line)   if line.displayOption
      choose_ads(line)            if line.size             != ""
      get_mediabuy_id(line)
      select_location(line)       if line.locationType     != ""
      select_start_date(line)     if line.start            != ""
      select_end_date(line)       if line.end              != ""
      #  set_notes_method(line)      if line.notes            != ""  ## have to be implemented
      set_targeting(line)
      set_price(line) unless ["time-based","timebased","sponsorship"].include?line.campaign.priceType.downcase
      set_budget(line)
      set_impression_goal(line) if ["time-based","timebased","sponsorship"].include?line.campaign.priceType.downcase
      sleep 5  * GlobalAdjustedSleepTime
      ## div(:id,/saveButtonsContainer/).link(:id,/#{$app.linkSaveBtnId}/).click
      ## $app = SalesTab.new
      link(:text,/Save/,3101).click
      sleep 8  * GlobalAdjustedSleepTime
      $logger.info "Line's part of the page is filled out Line name  <#{line.name}> id = <#{line.lineItemID}>" if line.lineItemID
    rescue       ## refresh
      sleep 5  * GlobalAdjustedSleepTime
      $logger.error("Create new line item <#{line.name}><#{$!}><#{$!.backtrace}> ")
      link(:text,/Save/,3101).click if link(:text,/Save/).exists?
      $app = LineItemPage.new
      sleep 8  * GlobalAdjustedSleepTime
    end
  end
  ###  ============================================================================
  def set_display_options(line)
    return $logger.testcase("set_display_options: Unexpected page <#{$app.name}> Exp: Edit Campaign::Line",1) unless $app.kind_of?LineItemPage
    begin
      click_edit_display_option(line)
      ##  Set Frequency
      if line.maxFrequency   ## true means unlimited
        radio(:id, /#{$app.rbFreqUnlimitedId}/).set
      else
        radio(:id, /#{$app.rbFreqLimitedId}/).set
        text_field(:id,/#{$app.tFreqImpressionsId}/).set line.mFrequencyLimit
        radio(:id, /#{$app.rbFreqPeriodicId}/).set
        select_list(:id,/#{$app.slFreqPeriodicUnitId}/).select "hour(s)"
        text_field(:id,/#{$app.tFreqPeriodQuantityId}/).set line.maxFrequencyAge   ## value in Hours
      end
      ##  Set Daily Impression Capping
      if line.dayImpressionCap.to_s  == "0"
        radio(:id, /#{$app.rbDailyCapNoneId}/).set
      else
        radio(:id, /#{$app.rbDailyCapLimitId}/).set
        text_field(:id,/#{$app.tDayCapId}/).set line.dayImpressionCap
      end
      ##  Set Pacing
      if line.pacingType  ## true means As evenly as possible
        radio(:id, /#{$app.rbPacingEvenlyId}/).set unless line.campaign.priceType.downcase == "time-based"
      else
        radio(:id, /#{$app.rbPacingFastId}/).set unless line.campaign.priceType.downcase == "time-based"
      end
      ##  Set Display
      if line.display.downcase == "standard" ## true means As evenly as possible
        radio(:id, /#{$app.rbDisplayStandardId}/).set
      elsif line.display.downcase == "anticompanion"
        radio(:id, /#{$app.rbDisplayNotSimultId}/).set
      elsif line.display.downcase == "companion"
        radio(:id, /#{$app.rbDisplayAllSimultId}/).set
      end
      ##  Set Priority
      if line.campaign.priceType.downcase != "time-based"
        option_to_select = select_list(:id,/#{$app.slPriorityId}/).getAllContents.find{|item| item.include?(line.priority)}
        select_list(:id,/#{$app.slPriorityId}/).select option_to_select
      end
      ##  Set Share of Network Optimization
      checkbox(:id,/#{$app.cbShareNetOptId }/).set  if checkbox(:id,/#{$app.cbShareNetOptId }/).exists? and line.sharedNetOpt
      link(:id,/#{$app.linkSaveId}/,3109).click
    rescue
      $logger.testcase("set_display_options for line item <#{line.name}><#{$!}><#{$!.backtrace}>",1)
      link(:id,/#{$app.linkSaveId}/,3109).click
    end
  end
  ### ============================================================================
  def select_start_date(line)
    return $logger.testcase("select_start_date: Unexpected page <#{$app.name}> Exp: Edit Campaign::Line",1) unless $app.kind_of?LineItemPage
    begin
      @table_lines = get_table_from_div($app.divLineItemTblId)
      column_index = @table_lines[0].to_a.index{|e| e =~ /Start/}
      @row_to_fill = find_row(@table_lines, 'Line item',line.name)
      dialog_date_field_set(@row_to_fill[column_index], line.start, "Start date for line item")
    rescue
      $logger.testcase("select_start_date for line item <#{line.name}><#{$!}><#{$!.backtrace}>",1)
    end
  end
  ### ============================================================================
  def select_end_date(line)
    return $logger.error("Unexpected page <#{$app.name}> Exp: Edit Campaign::Line") unless $app.kind_of?LineItemPage
    begin
      @table_lines = get_table_from_div($app.divLineItemTblId)
      column_index = @table_lines[0].to_a.index{|e| e =~ /End/}
      @row_to_fill = find_row(@table_lines, 'Line item',line.name)
      dialog_date_field_set(@row_to_fill[column_index],line.end,"End date for line item")
    rescue
      $logger.testcase("select_end_date for line item <#{line.name}><#{$!}><#{$!.backtrace}>",1)
    end
  end
  ### ============================================================================
  def choose_ads(line)
    return $logger.error("Unexpected page <#{$app.name}> Exp: Edit Campaign::Line") unless $app.kind_of?LineItemPage
    begin
      sleep 2 * GlobalAdjustedSleepTime
      @table_lines = get_table_from_div($app.divLineItemTblId)
      find_row(@table_lines, 'Line item',line.name).cell(:class,/AdSizes/).links[0].click
      sleep 3 * GlobalAdjustedSleepTime
      div(:id,/#{$app.divAddTableId}/).checkbox(:id,/#{$app.cbAllAddsId}/).set
#      div(:id,/#{$app.divAddTableId}/).checkbox(:id,/#{$app.cbAllAddsId}/).clear
#      tbl_edit_ads = get_table_from_div($app.divAddTableId)
#      for i in 1..tbl_edit_ads.row_count
#        if (tbl_edit_ads.row_values(i).length > 1)
#          if line.pickedAds.find {|creative| creative.name.gsub(/ */,"").include?(tbl_edit_ads.row_values(i)[1].gsub(/ */,""))}      ## Ignore space char when looking for creative's name
#            tbl_edit_ads[i][0].checkboxes[0].set
#          else
#            tbl_edit_ads[i][0].checkboxes[0].clear
#          end
#        end
#      end
      sleep 1  * GlobalAdjustedSleepTime
      link(:id,/#{$app.linkAddAdOkButtonId}/).click
    rescue => detail
      $logger.testcase("choose_ads for line item <#{line.name}> exception: <#{$!}> this is expected, probably watir bug <#{$!.backtrace[0].split(":").last}>",1) ## backtrace[0].split(":").last
      link(:id,/#{$app.linkAddAdOkButtonId}/).click
    end
  end
  ### =============================================================================
  def get_mediabuy_id(line)
    begin
      link(:id,/#{$app.linkSaveButtonId}/,3101).click
      sleep 40  * GlobalAdjustedSleepTime
      text_field(:id,/CampaignListSearchTerms/).set line.campaign.name
      button(:id,/CampaignListSearchButton/).click
      sleep 5 * GlobalAdjustedSleepTime
      link(:text, /#{line.campaign.name}/,3102).click
      sleep 2 * GlobalAdjustedSleepTime
      div(:id,/#{$app.divClientTabViewId}/).link(:text,/#{$app.linkLineItemsBtnItext}/).click
      sleep 6  * GlobalAdjustedSleepTime
      $app = LineItemPage.new
      @table_lines = get_table_from_div($app.divLineItemTblId)
      @row_to_fill = find_row(@table_lines, 'Line item',line.name)
      line.lineItemID = @row_to_fill[@table_lines.rows.find{|r| r.to_a.size > 1}.to_a.index("Campaign LI ID")].text
      ## line.lineItemID = @row_to_fill[@table_lines.row_values(1).index('ID')+1].text
      $logger.error("Wrong Line Item Id <#{line.lineItemID}>") unless line.lineItemID.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/)
      $logger.testcase("Line Item Id <#{line.lineItemID}>",0) if line.lineItemID.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/)
    rescue
      $logger.error("Exception in get_mediabuy_id <#{$!}><#{$!.backtrace}>")
      $app = LineItemPage.new
    end
  end
  ### =============================================================================
  def set_price(line)
    return $logger.error("Unexpected page <#{$app.name}> Exp: Edit Campaign::Line") unless $app.kind_of?LineItemPage
    begin
      @table_lines = get_table_from_div($app.divLineItemTblId)
      @row_to_fill = find_row(@table_lines, 'Line item',line.name)
      dialog_text_field_set(@row_to_fill.cell(:class,/Price/),line.price) if line.price != 0.to_s
    rescue
      $logger.testcase("set_price for line item <#{line.name}><#{$!}><#{$!.backtrace}>",1)
    end
  end
  ### =============================================================================
  def set_budget(line)
    return $logger.error("Unexpected page <#{$app.name}> Exp: Edit Campaign::Line") unless $app.kind_of?LineItemPage  ## $app.page_id != 3109
    begin
      @table_lines = get_table_from_div($app.divLineItemTblId)
      @row_to_fill = find_row(@table_lines, 'Line item',line.name)
      dialog_text_field_set(@row_to_fill.cell(:class,/Budget/),line.budget) if line.budget != 0.to_s
    rescue
      $logger.testcase("set_budget for line item <#{line.name}><#{$!}><#{$!.backtrace}>",1)
    end
  end
  ### =============================================================================
  def set_impression_goal(line)
    return $logger.error("Unexpected page <#{$app.name}> Exp: Edit Campaign::Line") unless $app.kind_of?LineItemPage   ## $app.page_id != 3109
    begin
      @table_lines = get_table_from_div($app.divLineItemTblId)
      @row_to_fill = find_row(@table_lines, 'Line item',line.name)
      dialog_text_field_set(@row_to_fill.cell(:class,/Count/),line.impressions.to_s) if line.impressions != 0.to_s
    rescue
      $logger.testcase("set_impression_goal for line item <#{line.name}><#{$!}><#{$!.backtrace}>",1)
    end
  end
  ### =============================================================================
  def select_location(line)
    $logger.info("Selecting location for line name <#{line.name}>")
    sleep 3
    begin
      return $logger.info("select_location: Unexpected page <#{$app.name}> Exp: Edit Campaign::Line") unless $app.kind_of?LineItemPage
      @table_lines = get_table_from_div($app.divLineItemTblId)
      find_row(@table_lines, 'Line item',line.name).cell(:class,/Location/).links[0].click
      $app = EditLocation.new
      case line.locationType.upcase
        when 'RUN OF NETWORK'
        link(:id,/#{$app.linkSaveBtnId}/,3109).click
        when  'ROT'
        select_rot_location(line)
        when  'RUN OF SITE'
        when 'NETWORK WIDGETS'
        select_widget_location(line)
        when  'FIXED NETWORK'
        select_fixnet_location(line)
      else
        $logger.info "Unexpected location for line item "
      end
    rescue
      $logger.error("select_location for line item <#{line.name}><#{$!}><#{$!.backtrace}>")
    end
    ## link(:id, /#{$app.linkSaveBtnId}/,3109).click
  end
  ### =============================================================================
  def go_to_lineItem_status_cell(line)
    link(:href,/#{$app.linkSalesHref}/, 3101).click if $app.kind_of?NetworkCS
    link(:id, /#{$app.linkCampaignsId}/, 3101).click
    sleep 2 * GlobalAdjustedSleepTime
    link(:text, /#{line.campaign.name}/,3102).click
    div(:id,/#{$app.divClientTabViewId}/).link(:text,/#{$app.linkLineItemsBtnItext}/).click
    sleep 2 * GlobalAdjustedSleepTime
    $app = LineItemPage.new
    @table_lines = get_table_from_div($app.divLineItemTblId)
    @row_to_fill = find_row(@table_lines, 'Line item',line.name)
    return @row_to_fill.cell(:class,/Status/)
  end
  ### =============================================================================
  def stop_line_item(line)
    $logger.info("Stop line Item <#{line.name}>")
    table_cell = go_to_lineItem_status_cell(line)
    dialog_select_list_set(table_cell,"Stopped", "Stop line item")
    link(:id,/#{$app.linkSaveButtonId}/).click
    link(:id,/#{$app.linkSaveButtonId}/,3101).click if text.include?("Are you sure") and link(:id,/#{$app.linkSaveButtonId}/).exists?
    link(:id,/#{$app.linkSaveButtonId}/).click if span(:id,/LineItemErrors/).exists?
        
    $app = SalesTab.new
  end
  ### =============================================================================
  def activate_line_item(line)
    logger.info "Stop line Item <#{line.name}>"
    table_cell = go_to_lineItem_status_cell(line)
    dialog_select_list_set(table_cell,"Active", "Activate line item")
    link(:id,/#{$app.linkSaveButtonId}/,3101).click
  end
  ### =============================================================================
  def select_fixnet_location(line)
    $logger.info "Selecting fix net location for line name <#{line.name}>"
    return $logger.info "Unexpected page <#{$app.name}> Exp: Edit Location" if $app.page_id != 3106
    sleep 10 * GlobalAdjustedSleepTime
    radio(:id, /#{$app.rbFixedNetSiteAdSpcId}/).set
    ### radio(:text, /#{$app.rbFixedNetItext}/).set
    sleep 1 * GlobalAdjustedSleepTime
    link(:text, /Save/).click if link(:text, /Save/).exists?
    select_adspaces_mb_location(line.locationList)
    link(:id,/#{$app.linkSaveBtnId}/,3109).click
  end
  ### =============================================================================
  def select_rot_location(line)
    $logger.info "Selecting run on tags location for line name <#{line.name}>"
    return $logger.info "Unexpected page <#{$app.name}> Exp: Edit Location" if $app.page_id != 3106
    sleep 6 * GlobalAdjustedSleepTime
    radio(:id,/#{$app.rbROTagId}/).set
    select_tags_mb_location(line)
    select_sites_mb_location(line.locationList.refine_by_sites)       if line.locationList.refine_by_sites    != []  ## if no data is  in xls then mb runs on all possible
    select_adspaces_mb_location(line.locationList.refine_by_adspaces) if line.locationList.refine_by_adspaces != []  ## sites ans ad spaces
    link(:id,/#{$app.linkSaveBtnId}/,3109).click
  end
  ### =============================================================================
  def select_widget_location(line)
    $logger.info "Selecting widget network location for line name <#{line.name}>"
    return $logger.info "Unexpected page <#{$app.name}> Exp: Edit Location"  if $app.page_id != 3106
    sleep 5 * GlobalAdjustedSleepTime
    radio(:id, /#{$app.rbNetWidgId}/).set
    sleep 1 * GlobalAdjustedSleepTime
    #    select_adspaces_mb_location(line.locationList)
    link(:id,/#{$app.linkSaveBtnId}/,3109).click
  end
  ### ============================================================================
  def remove_all_tags(s_list,remove_link)
    return unless s_list.kind_of?Watir::SelectList
    return unless remove_link.kind_of?Watir::Link
    while s_list.getAllContents[0] != nil
      s_list.select s_list.getAllContents[0]
      remove_link.click
    end
  end
  ### ============================================================================
  def select_tags_mb_location(line)
    $logger.info "Selecting tags for line name <#{line.name}>"
    return $logger.info "Unexpected page <#{$app.name}> Exp: Edit Location" if $app.page_id != 3106
    link(:id,/#{$app.linkEditTagId}/,3111).click
    link(:id,/#{$app.linkSaveDialogId}/,3111).click if link(:id,/#{$app.linkSaveDialogId}/).exists?
    sleep 2 * GlobalAdjustedSleepTime
    remove_all_tags(select_list(:id,/#{$app.slANDId}/),link(:id,/#{$app.linkRemoveANDId}/)) #####
    line.locationList.refine_by_tg_AND.each {|tag_and|
      text_field(:id, /#{$app.tSearchTagIncId}/).set tag_and.name
      button(:id,/#{$app.btnSearchId}/).click
      sleep 1 * GlobalAdjustedSleepTime
      option_to_select = select_list(:id,/#{$app.slAvailAdSpId}/).getAllContents.find{|item| item.include?(tag_and.name)}
      select_list(:id,/#{$app.slAvailAdSpId}/).select option_to_select if option_to_select
      button(:value,/#{$app.btnLctnANDValue}/).click                   if option_to_select
    }
    remove_all_tags(select_list(:id,/#{$app.slORId}/),link(:id,/#{$app.linkRemoveORId}/)) ####
    line.locationList.refine_by_tg_OR.each {|tag_or|
      text_field(:id, /#{$app.tSearchTagIncId}/).set tag_or.name
      button(:id,/#{$app.btnSearchId}/).click
      sleep 1 * GlobalAdjustedSleepTime
      option_to_select = select_list(:id,/#{$app.slAvailAdSpId}/).getAllContents.find{|item| item.include?(tag_or.name)}
      select_list(:id,/#{$app.slAvailAdSpId}/).select option_to_select if option_to_select
      button(:value,/#{$app.btnLctnORValue}/).click                    if option_to_select
    }
    image(:id,/#{$app.imgExcludeShowButtonId}/).click
    sleep 2 * GlobalAdjustedSleepTime
    remove_all_tags(select_list(:id,/#{$app.slNOTId}/),link(:id,/#{$app.linkRemoveNOTId}/))
    line.locationList.refine_by_tg_NOT.each {|tag_not|
      text_field(:id, /#{$app.tSearchTagExcId}/).set tag_not.name
      button(:id,/#{$app.btnSearchTagExcId}/).click
      sleep 1 * GlobalAdjustedSleepTime
      option_to_select = select_list(:id,/#{$app.slExlTagpId}/).getAllContents.find{|item| item.include?(tag_not.name)}
      select_list(:id,/#{$app.slExlTagpId}/).select option_to_select if option_to_select
      button(:value,/#{$app.btnLctnNOTValue}/).click                 if option_to_select
    }
    link(:id,/#{$app.linkSaveBtnId}/).click
    if text.include?"select at least one tag to continue"
      link(:id,/#{$app.linkCancelBtnId}/,3106).click
    else
      $app = EditLocation.new
    end
  end
  ### ============================================================================
  def select_sites_mb_location(sites)
    $logger.info "Selecting sites location for line item name"
    return $logger.info "Unexpected page <#{$app.name}> Exp: Edit Location" if $app.page_id != 3106
    link(:id,/#{$app.linkEditSitesId}/,3112).click
    link(:id,/#{$app.linkSaveDialogId}/,3112).click if link(:id,/#{$app.linkSaveDialogId}/,3112).exists?
    tabl = div(:id,/#{$app.divTblMainId}/).tables[0]
    checkbox(:id,/#{$app.cbAllItemsId}/).set
    checkbox(:id,/#{$app.cbAllItemsId}/).clear
    sites.each {|st|
      rowToFill = find_row(tabl, 'Site Name',st.name)
      rowToFill.checkboxs[0].set if rowToFill
      $logger.info("Site <#{st.name}>  is selected site id<#{st.site_Id}>")     if     rowToFill
      $logger.info("Site <#{st.name}>  isn't selected site id<#{st.site_Id}>")  unless rowToFill
    }
    link(:id,/#{$app.linkSaveBtnId}/,3106).click
  end
  ### ============================================================================
  def select_adspaces_mb_location(adspaces = [])
    $logger.info "Selecting ad spaces location for line item name"
    return $logger.info "Unexpected page <#{$app.name}> Exp: Edit Location" if $app.page_id != 3106
    link(:id,/#{$app.linkEditSpaceId}/,3113).click
    link(:id,/#{$app.linkSaveDialogId}/,3113).click if link(:id,/#{$app.linkSaveDialogId}/,3113).exists?
    sleep 2 * GlobalAdjustedSleepTime
    checkbox(:id,/#{$app.cbAllItemsId}/).set
    checkbox(:id,/#{$app.cbAllItemsId}/).clear
    adspaces.each {|as|
      checkbox(:id,/#{$app.cbAdSpaceId}#{as.o_Id}/).set if checkbox(:id,/#{$app.cbAdSpaceId}#{as.o_Id}/).exists? and as.o_Id !="" ## as.o_Id.kind_of?Fixnum
      $logger.error("Checkbox for adSpace's  <#{as.name}> id <#{as.o_Id}> is not found") unless checkbox(:id,/#{$app.cbAdSpaceId}#{as.o_Id}/).exists?
    }
    link(:id,/#{$app.linkSaveBtnId}/,3106).click
  end
  ### ============================================================================
  def set_targeting(line)
    $logger.info "Setting targeting for line item name <#{line.name}>"
    return $logger.error "Unexpected page <#{$app.name}> Exp: Edit Campaign::Line" if $app.page_id != 3109
    begin
      set_bt_targets(line)                 if line.bt_targeting.length != 0
      set_geo_targets(line)                if line.geo_targeting.kind_of?GeoTarget
      set_demographics_targets(line)       if line.demographics_targeting.kind_of?DemographicsTarget
    rescue
      $logger.testcase("set_targeting for line item <#{line.name}><#{$!}><#{$!.backtrace}>",1)
    end
  end
  ### ============================================================================
  def set_geo_targets(line)
    $logger.info "Setting geo targeting for line item name <#{line.name}>"
    begin
      click_edit_targeting(line)
      link(:text,$app.linkGeoItext,3114).click unless $app.page_id == 3114
      ### ==== Target Country, State, City
      image(:id, /#{$app.imShowCountryStateId}/).click if image(:id, /#{$app.imShowCountryStateId}/).exists? && image(:id, /#{$app.imShowCountryStateId}/).style.invoke('display') != "none"
      div(:id,/#{$app.divCountryId}/).button(:title,"Remove all items").click
      line.geo_targeting.countryInc.each { |country_inc|
        text_field(:id, /#{$app.tCountryStateCityId}/).set(country_inc)
        div(:id,/#{$app.divCountryId}/).button(:id,/#{$app.btnSearchCityStateCountryId}/).click
        sleep 1 * GlobalAdjustedSleepTime
        if select_list(:id,/#{$app.slAvailableLocationsId}/).exists?
          option_to_select = select_list(:id,/#{$app.slAvailableLocationsId}/).getAllContents.find{|item| item.include?(country_inc)}
          if option_to_select
            select_list(:id,/#{$app.slAvailableLocationsId}/).select(option_to_select)
            div(:id,/#{$app.divCountryId}/).button(:title,"Add selected items").click
          end
          if select_list(:id, /#{$app.slTargetedLocationsId}/).text.include?(country_inc)
            $logger.testcase("Line <#{line.name}> target <#{country_inc}> was selected ",0)
          else
            $logger.testcase("Line <#{line.name}> target <#{country_inc}> wasn't selected ",1)
          end
        end
        sleep 1 * GlobalAdjustedSleepTime
      }
      image(:id, /#{$app.imHideCountryStateId}/).click while image(:id,/#{$app.imHideCountryStateId}/).style.invoke('display') != "none"
      ### ==== Target US Metro Area
      sleep 1 * GlobalAdjustedSleepTime
      image(:id, /#{$app.imShowUSMetroId}/).click while image(:id, /#{$app.imShowUSMetroId}/).style.invoke('display') != "none"
      div(:id,/#{$app.divMetroUSId}/).button(:title,"Remove all items").click
      sleep 1 * GlobalAdjustedSleepTime
      line.geo_targeting.us_metroInc.each { |us_metro_inc|
        select_list(:id, /#{$app.slAvailableUSMetroId}/).getAllContents.each {|option|
          if option.to_s.include?us_metro_inc
            select_list(:id, /#{$app.slAvailableUSMetroId}/).clear
            select_list(:id, /#{$app.slAvailableUSMetroId}/).select(option)
            div(:id,/#{$app.divMetroUSId}/).button(:title,"Add selected items").click
            sl  = $app.targeted_metro_area_list(self)
            ## if select_list(:id, /#{$app.slTargetedUSMetroId}/).text.include?(us_metro_inc)
            if sl.include?(us_metro_inc)
              $logger.testcase("Line <#{line.name}> target <#{us_metro_inc}> was selected ",0)
            else
              $logger.testcase("Line <#{line.name}> target <#{us_metro_inc}> wasn't selected ",1)
            end
            sleep 2 * GlobalAdjustedSleepTime
          end
        }
      }
      image(:id,/#{$app.imHideUSMetroId}/).click while(image(:id,/#{$app.imHideUSMetroId}/).style.invoke('display') != "none")
      ### ==== Target UK Metro Area
      sleep 1 * GlobalAdjustedSleepTime
      image(:id, /#{$app.imShowUKMetroId}/).click while image(:id,/#{$app.imShowUKMetroId}/).style.invoke('display') != "none"
      div(:id,/#{$app.divMetroUKId}/).button(:title,"Remove all items").click
      sleep 1 * GlobalAdjustedSleepTime
      line.geo_targeting.uk_metroInc.each { |uk_metro_inc|
        #     select_list(:id, /#{$app.slAvailableUKMetroId}/).getAllContents { |options|
        select_list(:id, /#{$app.slAvailableUKMetroId}/).getAllContents.each { |option|
          if option.to_s.include?uk_metro_inc
            select_list(:id, /#{$app.slAvailableUSMetroId}/).clear
            select_list(:id, /#{$app.slAvailableUKMetroId}/).select(option)
            div(:id,/#{$app.divMetroUKId}/).button(:title,"Add selected items").click
            if select_list(:id, /#{$app.slAvailableUKMetroId}/).text.include?(uk_metro_inc)
              $logger.testcase("Line <#{line.name}> target <#{uk_metro_inc}> was selected ",0)
            else
              $logger.testcase("Line <#{line.name}> target <#{uk_metro_inc}> wasn't selected ",1)
            end
            sleep 1 * GlobalAdjustedSleepTime
          end
        }
      }
      #   }
      image(:id, /#{$app.imHideUKMetroId}/).click while image(:id, /#{$app.imHideUKMetroId}/).style.invoke('display') != "none"
      ### Target ZIP or Postal Code
      sleep 1 * GlobalAdjustedSleepTime
      image(:id, /#{$app.imShowZIPorPostalId}/).click while image(:id,/#{$app.imShowZIPorPostalId}/).style.invoke('display') != "none"
      div(:id,/#{$app.divZIPId}/).button(:title,"Remove all items").click
      line.geo_targeting.zipInc.each { |zip_inc|
        sleep 2 * GlobalAdjustedSleepTime
        text_field(:id, /#{$app.tPasteZIPorPostalId}/).set(zip_inc)
        div(:id,/#{$app.divZIPId}/).button(:title,"Add selected items").click
        if select_list(:id, /#{$app.slTargetedZIPId}/).text.include?(zip_inc)
          $logger.testcase("Line <#{line.name}> target <#{zip_inc}> was selected ",0)
        else
          $logger.testcase("Line <#{line.name}> target <#{zip_inc}> wasn't selected ",1)
        end
        sleep 1 * GlobalAdjustedSleepTime
      }
      image(:id, /#{$app.imHideZIPorPostalId}/).click while image(:id, /#{$app.imHideZIPorPostalId}/).style.invoke('display') != "none"
      ### ====Target Telephone Area Code
      sleep 1 * GlobalAdjustedSleepTime
      image(:id, /#{$app.imShowPhoneAreaCodeId}/).click while image(:id, /#{$app.imShowPhoneAreaCodeId}/).style.invoke('display') != "none"
      div(:id,/#{$app.divPhoneId}/).button(:title,"Remove all items").click
      line.geo_targeting.phone_areaInc.each { |phone_area_inc|
        sleep 2 * GlobalAdjustedSleepTime
        text_field(:id, /#{$app.tPastePhoneCodeId}/).set(phone_area_inc)
        div(:id,/#{$app.divPhoneId}/).button(:title,"Add selected items").click
        if select_list(:id, /#{$app.slTargetPhoneAreaCodesId}/).text.include?(phone_area_inc)
          $logger.testcase("Line <#{line.name}> target <#{phone_area_inc}> was selected ",0)
        else
          $logger.testcase("Line <#{line.name}> target <#{phone_area_inc}> wasn't selected ",1)
        end
        sleep 1 * GlobalAdjustedSleepTime
      }
      image(:id, /#{$app.imHidePhoneAreaCodeId}/).click while image(:id, /#{$app.imHidePhoneAreaCodeId}/).style.invoke('display') != "none"
      ### ====Target Country, State, City
      sleep 1 * GlobalAdjustedSleepTime
      image(:id, /#{$app.imNotShowCountryStateId}/).click if image(:id, /#{$app.imNotShowCountryStateId}/).style.invoke('display') != "none"
      div1 = div(:id,/#{$app.divNotCountryId}/)
      div1.button(:title,"Remove all items").click
      line.geo_targeting.countryExl.each { |country_exl|
        sleep 1  * GlobalAdjustedSleepTime
        text_field(:id, /#{$app.tNotCountryStateCityId}/).set(country_exl)
        div1.button(:id,/#{$app.btnNotSearchCityStateCountryId}/).click
        sleep 1 * GlobalAdjustedSleepTime
        if select_list(:id,/#{$app.slNotAvailableLocationsId}/).exists?
          option_to_select = select_list(:id,/#{$app.slNotAvailableLocationsId}/).getAllContents.find{|item| item.include?(country_exl)}
          select_list(:id,/#{$app.slNotAvailableLocationsId}/).select(option_to_select) if option_to_select
          div1.button(:title,"Add selected items").click
          if select_list(:id, /#{$app.slNotTargetedLocationsId}/).text.include?(country_exl)
            $logger.testcase("Line <#{line.name}> target <#{country_exl}> was selected ",0)
          else
            $logger.testcase("Line <#{line.name}> target <#{country_exl}> wasn't selected ",1)
          end
        end
      }
      image(:id, /#{$app.imNotHideCountryStateId}/).click while image(:id, /#{$app.imNotHideCountryStateId}/).style.invoke('display') != "none"
      ### Target US Metro Area
      sleep 1  * GlobalAdjustedSleepTime
      image(:id, /#{$app.imNotShowUSMetroId}/).click while image(:id, /#{$app.imNotShowUSMetroId}/).style.invoke('display') != "none"
      div(:id,/#{$app.divNotMetroUSId}/).button(:title,"Remove all items").click
      sleep 1  * GlobalAdjustedSleepTime
      line.geo_targeting.us_metroExl.each { |us_metro_exl|
        select_list(:id, /#{$app.slNotAvailableUSMetroId}/).getAllContents.each {|option|
          if option.include?(us_metro_exl)
            select_list(:id, /#{$app.slNotAvailableUSMetroId}/).clear
            select_list(:id, /#{$app.slNotAvailableUSMetroId}/).select(option)
            div(:id,/#{$app.divNotMetroUSId}/).button(:title,"Add selected items").click if button(:title,"Add selected items").exists?
            if select_list(:id, /#{$app.slNotTargetedUSMetroId}/).text.include?(us_metro_exl)
              $logger.testcase("Line <#{line.name}> target <#{us_metro_exl}> was selected ",0)
            else
              $logger.testcase("Line <#{line.name}> target <#{us_metro_exl}> wasn't selected ",1)
            end
            sleep 1  * GlobalAdjustedSleepTime
          end
        }
      }
      image(:id, /#{$app.imNotHideUSMetroId}/).click while image(:id, /#{$app.imNotHideUSMetroId}/).style.invoke('display') != "none"
      ### Target UK Metro Area
      sleep 1  * GlobalAdjustedSleepTime
      image(:id, /#{$app.imNotShowUKMetroId}/).click while image(:id, /#{$app.imNotShowUKMetroId}/).style.invoke('display') != "none"
      sleep 1  * GlobalAdjustedSleepTime
      div(:id,/#{$app.divNotMetroUKId}/).button(:title,"Remove all items").click
      line.geo_targeting.uk_metroExl.each { |uk_metro_exl|
        select_list(:id, /#{$app.slNotAvailableUKMetroId}/).getAllContents.each {|option|
          if option.include?uk_metro_exl
            select_list(:id, /#{$app.slNotAvailableUKMetroId}/).clear
            select_list(:id, /#{$app.slNotAvailableUKMetroId}/).select(option)
            div(:id,/#{$app.divNotMetroUKId}/).button(:title,"Add selected items").click
          end
          if select_list(:id, /#{$app.slNotAvailableUKMetroId}/).text.include?(uk_metro_exl.strip)
            $logger.testcase("Line <#{line.name}> target <#{uk_metro_exl}> was selected ",0)
          else
            $logger.testcase("Line <#{line.name}> target <#{uk_metro_exl}> wasn't selected ",1)
          end
          sleep 1  * GlobalAdjustedSleepTime
        }
      }
      image(:id, /#{$app.imNotHideUKMetroId}/).click while image(:id, /#{$app.imNotHideUKMetroId}/).style.invoke('display') != "none"
      ### ==== Target ZIP or Postal Code
      sleep 1  * GlobalAdjustedSleepTime
      image(:id, /#{$app.imNotShowZIPorPostalId}/).click while image(:id, /#{$app.imNotShowZIPorPostalId}/).style.invoke('display') != "none"
      sleep 1  * GlobalAdjustedSleepTime
      div(:id,/#{$app.divNotZIPId}/).button(:title,"Remove all items")
      sleep 1  * GlobalAdjustedSleepTime
      line.geo_targeting.zipExl.each { |zip_exl|
        text_field(:id, /#{$app.tNotPasteZIPorPostalId}/).set(zip_exl)
        div(:id,/#{$app.divNotZIPId}/).button(:title,"Add selected items").click if button(:title,"Add selected items").exists?
        if select_list(:id, /#{$app.slNotTargetedZIPId}/).text.include?(zip_exl.strip)
          $logger.testcase("Line <#{line.name}> target <#{zip_exl}> was selected ",0)
        else
          $logger.testcase("Line <#{line.name}> target <#{zip_exl}> wasn't selected ",1)
        end
        sleep 1  * GlobalAdjustedSleepTime
      }
      image(:id, /#{$app.imNotHideZIPorPostalId}/).click while image(:id, /#{$app.imNotHideZIPorPostalId}/).style.invoke('display') != "none"
      ### ==== Target Telephone Area Code
      image(:id, /#{$app.imNotShowPhoneAreaCodeId}/).click while image(:id, /#{$app.imNotShowPhoneAreaCodeId}/).style.invoke('display') != "none"
      div(:id,/#{$app.divNotPhoneId}/).button(:title,"Remove all items").click
      sleep 2 * GlobalAdjustedSleepTime
      line.geo_targeting.phone_areaExl.each { |phone_area_exl|
        text_field(:id, /#{$app.tNotPastePhoneCodeId}/).set(phone_area_exl)
        div(:id,/#{$app.divNotPhoneId}/).button(:title,"Add selected items").click if div(:id,/#{$app.divNotPhoneId}/).button(:title,"Add selected items").exists?
        if select_list(:id, /#{$app.slNotTargetPhoneAreaCodesId}/).text.include?(phone_area_exl.strip)
          $logger.testcase("Line <#{line.name}> target <#{phone_area_exl}> was selected ",0)
        else
          $logger.testcase("Line <#{line.name}> target <#{phone_area_exl}> wasn't selected ",1)
        end
        sleep 1 * GlobalAdjustedSleepTime
      }
      image(:id, /#{$app.imNotHidePhoneAreaCodeId}/).click while image(:id, /#{$app.imNotHidePhoneAreaCodeId}/).style.invoke('display') != "none"
      link(:id,/#{$app.linkSaveBtnId}/,3109).click
      if self.text.include?("The targets below were not recognized")
        $app = EditGeoTargeting.new
        $logger.error("Geo target for line item <#{line.name}>")
        link(:id,/#{$app.linkSaveBtnId}/,3109).click
      end
    rescue
      $logger.testcase("set_geo_targets:line item name <#{line.name}><#{$!}><#{$!.backtrace}>",1)
      link(:id,/#{$app.linkSaveBtnId}/,3109).click
    end
  end    ### set_geo_targets
  ### ============================================================================
  def set_demographics_targets(line)
    $logger.info "Setting demographic targeting for line item name <#{line.name}>"
    sleep 2 * GlobalAdjustedSleepTime
    @table_lines = get_table_from_div($app.divLineItemTblId)
    @row_to_fill = find_row(@table_lines, 'Line item',line.name)
    click_edit_targeting
    link(:text,$app.linkDemographItext,3115).click
    ### ==== Target Median household income
    image(:id, /#{$app.imShowIncomeId}/).click while image(:id, /#{$app.imShowIncomeId}/).style.invoke('display') != "none"
    div(:id,/#{$app.divIncomeId}/).checkbox(:id,/#{$app.cbIncomeNoTargetingId}/).set
    line.demographics_targeting.income.each { |lvl|
      div(:id,/#{$app.divIncomeId}/).checkbox(:id,/#{$app.cbIncomeLevelId.gsub("XXX",lvl.to_s)}/).set
      sleep 0.5 * GlobalAdjustedSleepTime
    }
    image(:id, /#{$app.imHideIncomeId}/).click while image(:id, /#{$app.imHideIncomeId}/).style.invoke('display') != "none"
    ### ==== Target Median age
    image(:id, /#{$app.imShowAgeId}/).click while image(:id, /#{$app.imShowAgeId}/).style.invoke('display') != "none"
    div(:id,/#{$app.divAgeId}/).checkbox(:id,/#{$app.cbAgeNoTargetingId}/).set
    line.demographics_targeting.age.each { |age|
      div(:id,/#{$app.divAgeId}/).checkbox(:id,/#{$app.cbAgeLevelId.gsub("XXX",age.to_s)}/).set
      sleep 0.5 * GlobalAdjustedSleepTime
    }
    image(:id, /#{$app.imHideAgeId}/).click while image(:id, /#{$app.imHideAgeId}/).style.invoke('display') != "none"
    ### ==== Target Children in household
    image(:id, /#{$app.imShowChildrenId}/).click while image(:id, /#{$app.imShowChildrenId}/).style.invoke('display') != "none"
    div(:id,/#{$app.divChildrenId}/).checkbox(:id,/#{$app.cbChildrenNoTargetingId}/).set
    line.demographics_targeting.children.each { |lvl|
      div(:id,/#{$app.divChildrenId}/).checkbox(:id,/#{$app.cbChildrenLevelId.gsub("XXX",lvl.to_s)}/).set
      sleep 0.5 * GlobalAdjustedSleepTime
    }
    image(:id, /#{$app.imHideChildrenId}/).click while image(:id, /#{$app.imHideChildrenId}/).style.invoke('display') != "none"
    ### ==== Target Education level
    image(:id, /#{$app.imShowEducationId}/).click while image(:id, /#{$app.imShowEducationId}/).style.invoke('display') != "none"
    div(:id,/#{$app.divEducationId}/).checkbox(:id,/#{$app.cbEducationNoTargetingId}/).set
    line.demographics_targeting.education.each { |lvl|
      div(:id,/#{$app.divEducationId}/).checkbox(:id,/#{$app.cbEducationLevelId.gsub("XXX",lvl.to_s)}/).set
      sleep 0.5 * GlobalAdjustedSleepTime
    }
    image(:id, /#{$app.imHideEducationId}/).click while image(:id, /#{$app.imHideEducationId}/).style.invoke('display') != "none"
    ### ==== Target Owner occupied household
    image(:id, /#{$app.imShowOwnerOccupiedId}/).click while image(:id, /#{$app.imShowOwnerOccupiedId}/).style.invoke('display') != "none"
    div(:id,/#{$app.divOwnerOccupiedId}/).checkbox(:id,/#{$app.cbOwnerOccupiedNoTargetingId}/).set
    line.demographics_targeting.owner_home.each { |lvl|
      div(:id,/#{$app.divOwnerOccupiedId}/).checkbox(:id,/#{$app.cbOwnerOccupiedLevelId.gsub("XXX",lvl.to_s)}/).set
      sleep 0.5 * GlobalAdjustedSleepTime
    }
    image(:id, /#{$app.imHideOwnerOccupiedId}/).click while image(:id, /#{$app.imHideOwnerOccupiedId}/).style.invoke('display') != "none"
    ### ==== Target Employment level
    image(:id, /#{$app.imShowEmploymentId}/).click while image(:id, /#{$app.imShowEmploymentId}/).style.invoke('display') != "none"
    div(:id,/#{$app.divEmploymentId}/).checkbox(:id,/#{$app.cbEmploymentNoTargetingId}/).set
    line.demographics_targeting.employment.each { |lvl|
      div(:id,/#{$app.divEmploymentId}/).checkbox(:id,/#{$app.cbEmploymentLevelId.gsub("XXX",lvl.to_s)}/).set
      sleep 0.5 * GlobalAdjustedSleepTime
    }
    image(:id, /#{$app.imHideEmploymentId}/).click while image(:id, /#{$app.imHideEmploymentId}/).style.invoke('display') != "none"
    link(:id,/#{$app.linkSaveBtnId}/,3109).click
    if self.text.include?("The targets below were not recognized")
      $app =  EditDemoTargeting.new
      $logger.error("Demographic target for line item <#{line.name}>")
      link(:id,/#{$app.linkSaveBtnId}/,3109).click
    end
  end ### set_demographic_targets
  ### ============================================================================
  def set_bt_targets(line)
    $logger.info "Setting bt targeting for line item name <#{line.name}>"
    line.bt_targeting.each { |sgmnt|
      click_edit_targeting(line)
      ## assign_Segment_to_LineItem(line,sgmnt)
      assign_segment_to_line_ltem(sgmnt)
    }
  end
  ### ============================================================================
  def click_edit_display_option(line_item = nil)
    return $logger.error "Unexpected page <#{$app.name}> Exp: Edit Campaign::Line" unless $app.kind_of?LineItemPage   ## if $app.page_id != 3109
    sleep 2 * GlobalAdjustedSleepTime
    @table_lines ||= get_table_from_div($app.divLineItemTblId)
    @row_to_fill = find_row(@table_lines,'Line item',line_item.name) if line_item
    @row_to_fill.checkboxes[0].set
    select_list(:id,/#{$app.slEditId}/).select("Edit display options")
    button(:id,/#{$app.btnGoId}/,3116).click
    sleep 2 * GlobalAdjustedSleepTime
    link(:id, /SaveDialog_Save/).click if text.include?("Do you want to save changes")
    sleep 3 * GlobalAdjustedSleepTime
  end
  ### ============================================================================
  def click_edit_targeting(line_item = nil)
   ($logger.error("Unexpected page <#{$app.name}> Exp: Edit Campaign::Line"); return) unless $app.kind_of?LineItemPage   ##if $app.page_id != 3109
    sleep 4 * GlobalAdjustedSleepTime
    @table_lines = get_table_from_div($app.divLineItemTblId)
    @row_to_fill = find_row(@table_lines,'Line item',line_item.name) if line_item
    ## @row_to_fill[@table_lines.row_values(1).index('Line item')].links[0].click
    @row_to_fill.cell(:class,/Edit/).link(:text,/Actions/).click
    sleep 1 * GlobalAdjustedSleepTime
    link(:id,/#{$app.linkEditTargetingId}/,3114).click
    link(:id, /SaveDialog_Save/).click if text.include?("Do you want to save changes")
    sleep 3 * GlobalAdjustedSleepTime
  end
  ### ============================================================================
  ### Code for new Edit Ads Page
  ### ============================================================================
  def fill_out_EmptyAd(ad)
    $logger.info "Filling data for creative(ad) <#{ad.name}>"
    return if $app.page_id != 3103
    sleep 3 * GlobalAdjustedSleepTime
    if ad.type.upcase.include?'HTML'
      set_ad_name(ad.name)
      set_ad_size(ad.adSize)
      set_ad_destination_url(ad.destinationURL)
      set_ad_code(ad.code)
##      set_ad_attribute_none
    elsif  ad.type.upcase.include?'IMAGE'
      file_field(:name,/#{$app.fileFieldName}/).set ad.file
      link(:id,/#{$app.linkUploadAdsBtnId}/).click
    end
    link(:id,/#{$app.linkSaveButton}/, 3102).click
  end
  ### ============================================================================
  def getSegmentId(segment)
    return nil if $app.page_id != 3301
    text_field(:id,/#{$app.tSegmentSearchId}/).set segment.name
    link(:id,/#{$app.linkSearchBtnId}/).click
    sleep 2 * GlobalAdjustedSleepTime
    verify_text_exists("Verify that Search Segment Button is working for <#{segment.name}>",segment.name)
    sleep 1 * GlobalAdjustedSleepTime
    tbl = get_table_from_div($app.divTableResultSearchId)
    my_row = find_row(tbl, "Segment", segment.name)
    my_row.cell(:class,/Actions/).link(:text,/#{$app.linkActionsItext}/).click
    link(:id,/#{$app.linkIditId}/).click
    sleep 1 until url.include? "segmentId="
    segment.segmentID = url.sub(/.*segmentId=/,'').strip
  end
  ### ============================================================================
  def fill_out_CreateSegment(segment)
    if $app.page_id == 3301
      link(:id,/#{$app.linkCreateSegmentBtnId}/).click
      verify_object_exists(text_field(:id,/#{$app.tSegmentNameId}/))
      verify_text_exists('Verify that application navigates user to Edit Segment Page after clicking on Create Segment Button','This segment includes all users')
      text_field(:id,/#{$app.tSegmentNameId}/).set segment.name
      text_field(:id,/#{$app.tSegmentDescriptionId}/).set segment.segmentDescription
      link(:id,/#{$app.linkSaveButtonId}/).click
      verify_text_exists("Create Segment <#{segment.name}>",'Target your campaigns to visitors')
      getSegmentId(segment)
      $logger.info "Create Segment page is filled out for segment #{segment.name}"
    else
      $logger.info "Unexpected page id <#{$app.page_id}> expected id is 3301."
    end
  end
  ### ============================================================================
  def delete_Segment(segment)
    if $app.page_id == 3301
      text_field(:id,/#{$app.tSegmentSearchId}/).set segment.segmentID
      link(:id,/#{$app.linkSearchBtnId}/).click
      tbl = get_table_from_div($app.divTableResultSearchId)
      my_row = find_row(tbl, "Segment", segment.name)
      my_row.cell(:class,/Actions/).link(:text,/#{$app.linkActionsItext}/).click
      link(:text,'delete').click
      span(:id,/#{$app.spamDeleteSegmentOKButtonId}/).link(:id,/#{$app.linkDeleteSegmentOKButtonId}/).click
      text_field(:id,/#{$app.tSegmentSearchId}/).set segment.segmentID
      link(:id,/#{$app.linkSearchBtnId}/).click
      if verify_text_does_not_exist("Delete behavioral segment that is not assigned to an existing campaign", segment.name)== 0
        $logger.info "Segment <#{segment.name}> was deleted successfully"
        return segment
      end
    else
      $logger.info "Unexpected page id <#{$app.page_id}> expected id is 3301."
    end
  end
  ### ============================================================================
  def verify_text_exists(testCaseName,result_string)
    sleep 1   * GlobalAdjustedSleepTime
    if contains_text(result_string)
      $logger.testcase(testCaseName, 0)
      return 0
    else
      $logger.testcase(testCaseName, 1)
      return 1
    end
  end
  ### ============================================================================
  def verify_text_does_not_exist(testCaseName,result_string)
    sleep 1   * GlobalAdjustedSleepTime
    if contains_text(result_string)
      $logger.testcase(testCaseName, 1)
      return 1
    else
      $logger.testcase(testCaseName, 0)
      return 0
    end
  end
  ### ============================================================================
  def verify_object_exists(object)
    i = 0
    sleep 1 * GlobalAdjustedSleepTime
    until object.exists?
      sleep 1 * GlobalAdjustedSleepTime
      i += 1
      if i == 30
        break
        $logger.error("Object <#{object}> does not exist on the #{title()} Page")
      end
    end
  end
  ### ============================================================================
  def getBeaconTags(beacon)
    return if $app.page_id != 3302
    text_field(:id,/#{$app.tBeaconSearchId}/).set beacon.beaconID
    link(:id,/#{$app.linkSearchBtnId}/).click
    sleep 1 until checkbox(:id, /#{$app.cbSelectBeaconHeaderId}/).exists?
    checkbox(:id, /#{$app.cbSelectBeaconHeaderId}/).set
    link(:id,/#{$app.linkEditSelectedBeaconsBtnId}/).click
    link(:id,/#{$app.linkGetBeaconTagsBtnId}/).click
    sleep 1 until url.include? "GetPixelBeaconTag"
    beacon.beaconImageTag = textField(:id,/#{$app.tImageTagBeaconId}/).value   if textField(:id,/#{$app.tImageTagBeaconId}/).exists?
    beacon.beaconJavaScriptTag = textField(:id,/#{$app.tJSTagBeaconId}/).value if textField(:id,/#{$app.tJSTagBeaconId}/).exists?
    beacon.beaconID = url.sub(/.*beaconIds=/,'').strip
    verify_text_exists("Get Beacon Tag <Image Tag> for Beacon <#{beacon.name}>",'Image tag')
    verify_text_exists("Get Beacon Tag <JavaScript Tag> for Beacon <#{beacon.name}>",'JavaScript tag')
    back()
  end
  ### ============================================================================
  def fill_out_CreateBeaconPix(beacon)
    sleep 1  * GlobalAdjustedSleepTime
    if $app.page_id == 3302
      link(:id,/#{$app.linkCreateBeaconBtnId}/).click
      text_field(:id,/#{$app.tEditBeaconNameId}/).set beacon.name
      text_field(:id,/#{$app.tEditBeaconDaysId}/).set beacon.beaconDays
      text_field(:id,/#{$app.tEditBeaconEncountersId}/).set beacon.beaconEncounters
      link(:id,/#{$app.linkEditBeaconsSaveBtnId}/).click
      sleep 2 until url.include? "showBeaconId="
      beacon.beaconID = url.sub(/.*showBeaconId=/,'').strip
      verify_object_exists(checkbox(:id, /#{$app.cbSelectBeaconId}/))
      sleep 3  * GlobalAdjustedSleepTime
      verify_text_exists("Create Pixel Beacon <#{beacon.name}>",beacon.name)
      checkbox(:id, /#{$app.cbSelectBeaconId}/).set
      link(:id,/#{$app.linkEditSelectedBeaconsBtnId}/).click
      link(:id,/#{$app.linkGetBeaconTagsBtnId}/).click
      sleep 1 until url.include? "GetPixelBeaconTag"
      beacon.beaconImageTag = textField(:id, /#{$app.tImageTagBeaconId}/).value
      beacon.beaconJavaScriptTag = textField(:id, /#{$app.tJSTagBeaconId}/).value
      verify_text_exists("Get Beacon Tag <Image Tag> for Beacon <#{beacon.name}>",'Image tag')
      verify_text_exists("Get Beacon Tag <JavaScript Tag> for Beacon <#{beacon.name}>",'JavaScript tag')
      #      link(:text,/#{$app.linkEditPixelBeaconsItext}/,3302).click
      $logger.info "Pixel beacon <#{beacon.name}> id <#{beacon.beaconID}> has been created"
    else
      $logger.error "Unexpected page id <#{$app.page_id}> expected id is 3302."
    end
  end
  ### ============================================================================
  ### The method creates AdSpace beacon
  ### TO DO add steps for RON and ROS types - AA 2009/12/04
  ### ============================================================================
  def fill_out_CreateBeaconAS(beacon)
    sleep 1 * GlobalAdjustedSleepTime
    if $app.page_id != 3303
      $logger.error "Unexpected page id <#{$app.page_id}> expected id is 3303."
    end
    link(:id,/#{$app.linkCreateBeaconBtnId}/).click
    text_field(:id,/#{$app.tEditBeaconNameId}/).set beacon.name
    text_field(:id,/#{$app.tEditBeaconDaysId}/).set beacon.beaconDays
    text_field(:id,/#{$app.tEditBeaconEncountersId}/).set beacon.beaconEncounters
    link(:id,/#{$app.linkEditBeaconsSaveBtnId}/).click
    sleep 2 until url.include? "showBeaconId="
    beacon.beaconID = url.sub(/.*showBeaconId=/,'').strip  ###
    link(:id,/#{$app.linkSelectASButId}/, 3106).click      ### 3304
    case beacon.location.type
      when 'Entire networks'
      checkbox(:id, /#{$app.cbEntireNetworksId}/).set
      when 'Entire sites'
      checkbox(:id, /#{$app.cbEntireSitesId}/).set
      when 'Specific ad spaces'
      beacon.beaconJavaScriptTag = beacon.location.b_objects[0].tag
      beacon.beaconImageTag = beacon.location.b_objects[0].tag
      select_adspaces_mb_location(beacon.location.b_objects)
    else
      $logger.info "Unknown location type <#{beacon.location.type}> for beacon <#{beacon.name}>"
    end
    
    $logger.info "Adspace beacon <#{beacon.name}> id <#{beacon.beaconID}> has been created"
  end
  ### ============================================================================
  def delete_Beacon(beacon)
    if $app.page_id == 3302
      text_field(:id,/#{$app.tBeaconSearchId}/).set beacon.beaconID
      link(:id,/#{$app.linkSearchBtnId}/).click
      verify_object_exists(table(:id,/#{$app.tableAllBeaconsId}/))
      verify_object_exists(checkbox(:id, /#{$app.cbSelectBeaconId}/))
      checkbox(:id, /#{$app.cbSelectBeaconId}/).set
      link(:id,/#{$app.linkEditSelectedBeaconsBtnId}/).click
      link(:id,/#{$app.linkDeleteBeaconsBtnId}/).click
      link(:id,/#{$app.linkDeleteBeaconOKButtonId}/).click
      verify_object_exists(table(:id,/#{$app.tableAllBeaconsId}/))
      if verify_text_does_not_exist("Delete Beacon that is not assigned to an existing Segment", beacon.name)== 0
        $logger.info "Beacon <#{beacon.name}> was deleted successfully"
        return beacon
      end
    else
      $logger.info "Unexpected page id <#{$app.page_id}> expected id is 3302."
    end
  end
  ### ============================================================================
  def assign_Beacon_to_Segment(segment,beaconSeg)
    if $app.page_id == 3301
      text_field(:id,/#{$app.tSegmentSearchId}/).set segment.segmentID.to_s
      link(:id,/#{$app.linkSearchBtnId}/).click
      sleep 2 * GlobalAdjustedSleepTime
      tbl = get_table_from_div($app.divTableResultSearchId)
      my_row = find_row(tbl, "Segment", segment.name)
      my_row.cell(:class,/Actions/).link(:text,/#{$app.linkActionsItext}/).click
      link(:text,'Edit').click
      text_field(:id,/#{$app.tSearchAvailableBeaconsId}/).set beaconSeg.beacon.beaconID
      link(:id,/#{$app.linkSearchAvailableBeaconsButtonId}/).click
     ## verify_object_exists(table(:id,/#{$app.tableAvailableBeaconsId}/))
      sleep 3 * GlobalAdjustedSleepTime
      ## tbl_beacons = get_table_from_div($app.tableAvailableBeaconsId)
      tbl_beacons = get_table_from_div($app.divAvailableBeaconsGridId)
      row_my_beacon = find_row(tbl_beacons, "Beacon",beaconSeg.beacon.name)
      row_my_beacon.link(:text,'assign').click
      link(:text,/#{$app.linkAssignedBeaconsText}/).click
      radio(:id, /#{$app.rbAssignedBeaconsAndId}/).set if segment.condition.to_s.upcase == 'AND'
      radio(:id, /#{$app.rbAssignedBeaconsOrId}/).set if segment.condition.to_s.upcase == 'OR'
      row = find_row(table(:id,/#{$app.tAssignedBeaconsGridId}/), 'Beacon', beaconSeg.beacon.name)
      row.select_lists[0].select beaconSeg.option
      link(:id,/#{$app.linkSaveButtonId}/).click
      $logger.info "Beacon <#{beaconSeg.beacon.name}> has been assigned to Segment <#{segment.name}>"
      verify_text_exists("Save Segment <#{segment.name}> with assigned Beacon <#{beaconSeg.beacon.name}>",'Target your campaigns to visitors')
      sleep 4
    else
      $logger.error "Unexpected page id <#{$app.page_id}> expected id is 3301."
    end
  end
  ### ============================================================================
  def remove_Beacon_from_Segment (segment,beacon)
    sleep 1  * GlobalAdjustedSleepTime
    return ($logger.error "Unexpected page id <#{$app.page_id}> expected id is 3301.") unless $app.page_id == 3301
    text_field(:id,/#{$app.tSegmentSearchId}/).set segment.segmentID
    link(:id,/#{$app.linkSearchBtnId}/).click
    verify_object_exists(table(:id,/#{$app.tableAvailableSegmentsId}/))
    table(:id,/#{$app.tableAvailableSegmentsId}/)[table(:id,/#{$app.tableAvailableSegmentsId}/).column_values(1).index(segment.name) + 1][3].link(:text,'edit').click
    link(:text,/#{$app.linkAssignedBeaconsText}/).click
    verify_object_exists(table(:id,/#{$app.tableAssignedBeaconsId}/))
    table(:id,/#{$app.tableAssignedBeaconsId}/)[table(:id,/#{$app.tableAssignedBeaconsId}/).column_values(5).index(beacon.beaconID) + 1][7].link(:text,'remove').click
    link(:id,/#{$app.linkSaveButtonId}/).click
    segment.beacons.delete(beacon)
    $logger.info "Beacon <#{beacon.name}> has been removed from Segment <#{segment.name}>"
  end
  ### ============================================================================
  def assign_Segment_to_LineItem(lineItem,segment)
    sleep 2 * GlobalAdjustedSleepTime
    return ($logger.error "Unexpected page id <#{$app.page_id}> expected kind_of EditTargeting.") unless $app.kind_of?EditTargeting
    link(:text,$app.linkBehavioralItext,3105).click
    verify_object_exists(text_field(:id,/#{$app.tBehavioralSegmentSearchId}/))
    text_field(:id,/#{$app.tBehavioralSegmentSearchId}/).set segment.name.to_s
    button(:id,/#{$app.btnBehavioralSegmentSearchId}/).click
    verify_object_exists(select_list(:id,/#{$app.slAvailableSegmentsId}/))
    select_list(:id,/#{$app.slAvailableSegmentsId}/).select(segment.name)
    button(:name,/#{$app.btnMoveBehavioralSegmentToRightName}/).click
    link(:id,/#{$app.linkSaveButtonId}/,3109).click
    sleep 2 * GlobalAdjustedSleepTime
    $logger.info "Line Item <#{lineItem.name}> has been targeted to Segment <#{segment.name}>"
  end
  ### 6.5 release ============================================================================
  def assign_segment_to_line_ltem(segment)
    sleep 8 * GlobalAdjustedSleepTime
    begin
      return ($logger.error "Unexpected page id <#{$app.page_id}> expected kind_of EditTargeting.") unless $app.kind_of?EditTargeting
      link(:text,$app.linkBehavioralItext,3105).click
      text_field(:id,/#{$app.tStandardCDSSegmentsTextBoxId}/).set segment.name.to_s
      button(:id,/#{$app.btnStandardCDSSegmentsSearchButtonId}/).click
      sleep 5 * GlobalAdjustedSleepTime
      link(:text,/#{$app.linkSelectItext}/).click
      link(:id,/#{$app.linkSaveButtonId}/,3109).click
    rescue => e
      $logger.error("Assign segment to line item targeting<#{segment.name}>")
      $logger.info("#{e.message}")
    end
    $logger.info "Line Item set to target segment <#{segment.name}>"
  end
  ### 6.5 release ============================================================================
  def remove_segment_from_line_item(segment)
    sleep 2 * GlobalAdjustedSleepTime
    begin
      return ($logger.error "Unexpected page id <#{$app.page_id}> expected kind_of EditTargeting.") unless $app.kind_of?EditTargeting
      link(:text,$app.linkBehavioralItext,3105).click
      tbl = get_table_from_div($app.divTargetedSegmentsTblId)
      my_row = find_row(tbl, "Segments", segment.name)
      my_row.link(:text,/#{$app.linkRemoveItext}/).click if my_row.link(:text,/#{$app.linkRemoveItext}/).exists?
      link(:id,/#{$app.linkSaveButtonId}/,3109).click
    rescue => e
      $logger.error("Remove segment from line item <#{segment.name}>")
      $logger.error("#{e.message}")
    end
  end
  ### ============================================================================
  def remove_Segment_from_LineItem (line_item,segment)
    sleep 2 * GlobalAdjustedSleepTime
    return ($logger.error "Unexpected page id <#{$app.page_id}> expected kind_of EditTargeting.") unless $app.kind_of?EditTargeting
    link(:text,$app.linkBehavioralItext,3105).click
    if (select_list(:id,/#{$app.slTargetSegmentsId}/).exists?) && (select_list(:id,/#{$app.slTargetSegmentsId}/).getAllContents.include?segment.name)
      select_list(:id,/#{$app.slTargetSegmentsId}/).select(segment.name)
    end
    button(:name,/#{$app.btnMoveBehavioralSegmentToLeftName}/).click
    link(:id,/#{$app.linkSaveButton}/,3102).click
    link(:id,/#{$app.linkSaveBtnId }/).click
    sleep 1 * GlobalAdjustedSleepTime
    $logger.info "Segment <#{segment.name}> has been removed from Line Item <#{line_item.name}> Behavioral Targeting>"
  end
  ### ============================================================================
  ## method set up default Ad spaces for the network
  ### ============================================================================
  def setDefaultAdSpaces(defaultAdSpaces)
    @defaultAdSpaces = defaultAdSpaces
    if $app.is_a?(NetworkTab)
      ## looking for 4 tables with checkboxes
      tables.each do |tabl|
        @tableSkySkrapers = tabl if tabl.text.index("Skyscraper") == 0
        @tableBanners = tabl     if tabl.text.index("Leaderboard") == 0
        @tableRectangles = tabl  if tabl.text.index("Medium Rectangle") == 0
      end
      @tableSkySkrapers.rows.each { |r|  r[1].checkboxes[0].clear } #if r.column_count == 4 }
      @tableBanners.rows.each     { |r|  r[1].checkboxes[0].clear } #if r.column_count == 4 }
      @tableRectangles.rows.each  { |r|  r[1].checkboxes[0].clear } #if r.column_count == 4 }
      ## check all default ad spaces
      @defaultAdSpaces.each do |adSpace|
        @tableSkySkrapers.rows.each { |r|
          if r.column_count == 4
            if (r[2].text.include?(adSpace.size)||r[2].text.include?(adSpace.size.gsub('x',' x ')))&&(not adSpace.name.upcase.include?'TEXT')
              r[1].checkboxes[0].set
              $logger.testcase("Default Ad Space name: <#{adSpace.name}> size: <#{adSpace.size}> is selected", 0)
            end
          end
        }
        @tableBanners.rows.each do |r|
          if r.column_count == 4
            if (r[2].text.include?(adSpace.size)||r[2].text.include?(adSpace.size.gsub('x',' x ')))&&(not adSpace.name.upcase.include?'TEXT')
              r[1].checkboxes[0].set
              $logger.testcase("Default Ad Space name: <#{adSpace.name}> size: <#{adSpace.size}> is selected", 0)
            end
          end
        end
        @tableRectangles.rows.each { |r|
          if r.column_count == 4
            if (r[2].text.include?(adSpace.size)||r[2].text.include?(adSpace.size.gsub('x',' x ')))&&(not adSpace.name.upcase.include?'TEXT')
              r[1].checkboxes[0].set
              $logger.testcase("Default Ad Space name: <#{adSpace.name}> size: <#{adSpace.size}> is selected", 0)
            end
          end
        }
      end
    else
      $logger.info("Unexpected page id <#{$app.page_id}> expected id is 21..")
    end
  end
  ### ============================================================================
  ## Method to find index of the column row in the table with text(include?) 
  ### ============================================================================
  def find_column_index(tbl,col_name)
    # first_row = tbl.rows.find{|r| r.column_count > 1}
    first_row = tbl.trs.find{|r| r[0].exists? }
    index = 0
  #  @col_num = 0
  ##  first_row.each{|c|
  ## (@col_num = index; break) if first_row.tds[index].text.strip.downcase == col_name.strip.downcase 
  #   index +=1}
  # return @col_num
  while  index < tbl.tds.length ## (first_row.tds[index].text == first_row.tds.last.text) 
      break if first_row[index].text.strip.downcase == col_name.strip.downcase
      index +=1
  end
    return index
  end
  ### ============================================================================
  ## Method to find all rows having table, index of the column and text in this column
  ### ============================================================================
  def find_rows_index(tbl,column_index,text)
    rows=[]
    length_of_text_limit = (text.length<30)?(text.length):33
    text_to_find = text[0,length_of_text_limit]
  #  for i in  0..tbl.row_count - 2
    for i in  0..tbl.trs.length - 2
   ##  puts i
     rows << i if  (tbl[i].tds.length > column_index) && (tbl[i][column_index].text.strip =~ /#{text_to_find.strip}/ )
     ## rows << i  if  (tbl.row_values(i).length > column_index) && (tbl.row_values(i)[column_index].strip =~ /#{text_to_find.strip}/ )
    end
    $logger.error("find_row method: Text #{text_to_find} in column # <#{column_index}> is not found") if rows.length == 0
    return rows
  end
  ### ============================================================================
  ## Method to find row having table, index of the column and text in this column
  ### ============================================================================
  def find_row_index(tbl,column_index,text)
    length_of_text_limit = (text.length<25)?(text.length):25
    text_to_find = text[0,length_of_text_limit]
   ## for i in  0..tbl.row_count - 1
    for i in  0..tbl.trs.length - 1
      # return tbl[i] if  (tbl.row_values(i).length > column_index) && (tbl.row_values(i)[column_index].strip =~ /#{text_to_find.strip}/ )
      return tbl[i] if  (tbl[i].tds.length > column_index) && (tbl[i][column_index].text.strip =~ /#{text_to_find.strip}/ )
    end
    $logger.error("find_row method: Text #{text_to_find} in column # <#{column_index}> is not found")
    return nil
  end
  ### ============================================================================
  ## Method to find row in the table with text(include?) in the 'column' with name ""
  ### ============================================================================
  def find_row(tbl,col_name,text)
    column_index = find_column_index(tbl,col_name)  ## look here
    return find_row_index(tbl,column_index,text)
  end
  ### ============================================================================
  ## Collect all Ad Tags from application and assign them to site's ad spaces
  ### ============================================================================
  def get_ad_tags(site)
    sleep 6 * GlobalAdjustedSleepTime
    table1 = get_table_from_div($app.tableSiteMainId)
    my_row = find_row(table1, 'Site', site.name)
 ##   my_row = find_row(table1, 'Site URL', site.url)
    if my_row
      my_row.cell(:class,/SiteActions/).links[0].click
      sleep 1
      link(:id,/#{$app.linkGetAdTagId}/,2104).click
      sleep 6 * GlobalAdjustedSleepTime
      adiv = (divs.collect{|d| d.text_field(:id,/#{$app.textAdTagId}/).text.to_s if d.id.to_s.match(/#{$app.divAdTagsId}/)}).compact
      site.adSpaces.each do |adSpace|   ## assigning ad tags to corresponded bo site's ad spaces
        adSpace.tag = ""
        adiv.each do |tag|
          if adSpace.default
            adSpace.tag = tag if tag.include?adSpace.size.gsub(/ /,'')  ## adSpace.name.gsub(/[\s_]*/,'')
          else
            adSpace.tag = tag  if tag.include?adSpace.name.gsub(/[\s_]*/,'')
          end
        end
        adSpace.o_Id = adSpace.tag.match(/sr_adspace_id = (\d*)/)[1].to_s.strip  if adSpace.tag != ""
      end
      $logger.info "There are  <#{site.adSpaces.length}> adSpaces and <#{adiv.length}> adTags" if adiv.length != site.adSpaces.length
    else
      $logger.info "Error Site name <#{site.name}> was not found"
    end
    link(:id,/#{$app.linkDoneBtnId}/,2101).click
  end

  def get_smart_ad_tags(site)
    sleep 60 ##  vvv
    sleep 2 * GlobalAdjustedSleepTime
    table1 = get_table_from_div($app.tableSiteMainId)
    my_row = find_row(table1, 'Site', site.name)
    #  ie.link(:id,/#{$app.linkSaveBtnId}/,3101).click
    begin
      my_row.cell(:class,/SiteActions/).links[0].click
      sleep 0.5 * GlobalAdjustedSleepTime
      link(:id,/#{$app.linkGetAdTagId}/,2104).click
      sleep 2 * GlobalAdjustedSleepTime
      table_check_boxes = get_table_from_div("AdZoneTable")
      if table_check_boxes.trs.length < 3
        link(:id,/BodyContent_backButton/).click
        sleep 2
        raise "no ad spaces tags for site #{site.name}"
      end
    rescue Exception => e
      $logger.info("Get ad space tag exception: #{e}")
      sleep 2 * GlobalAdjustedSleepTime
      look_up_site_on_site_page(site)
     # sleep 2 * GlobalAdjustedSleepTime
      table1 = get_table_from_div(/SiteTable/)
      my_row = find_row(table1, 'Site', site.name)
      my_row.cell(:class,/SiteActions/).links[0].click
      sleep 0.5 * GlobalAdjustedSleepTime  ## vvv 0.3
      link(:id,/#{$app.linkGetAdTagId}/,2104).click
      table_check_boxes = get_table_from_div("AdZoneTable")
    end  
    ## collect all ad tags
    ## table_check_boxes = get_table_from_div("AdZoneTable")
    ## for i in  0..table_check_boxes.row_count - 1
    $logger.error("Cannot get Smart tag - no checkboxes present on Get AdTag Page") if table_check_boxes.trs.length < 3
     puts "checkboxes  "+ "#{table_check_boxes.trs.length}"
     for i in  0..table_check_boxes.trs.length - 1  
      if table_check_boxes[i].checkbox(:id,/AdZoneTable/).present? ## vlad changed exists? to present?  
        table_check_boxes[i].checkbox(:id,/AdZoneTable/).set
        sleep 1.5   ## vvv 0.5
        a = AdSpace.new
        ## a.tag = text_field(:id,"ctl00_ctl00_BodyContent_BodyContent_ctl04_pageTag").text.to_s
        a.tag = textarea(:id,/BodyContent_ctl04_pageTag/).value
        a.default = false
        site.adSpaces << a
        table_check_boxes[i].checkbox(:id,/AdZoneTable/).clear
        sleep 1.5   ## vvv 0.5
      end
    end
    $logger.info "get_smart_ad_tags method"
    link(:text,"Back",2101).click
  end
  ### =============================================================================
  ## Collect all Widget Tags from application and assign them to site's widget spaces
  ### =============================================================================
  def getWidgetTags(site)
   ($logger.error "Unexpected page :<#{$app.name}>"; return)          unless $app.kind_of?SitesAndPubNB
    table1 = get_table_from_div($app.tableSiteMainId)
    my_row = find_row(table1, 'Site', site.name)
    if my_row
      my_row.cell(:class,/SiteActions/).links[0].click
      link(:id,/#{$app.linkGetWidgetTagId}/,2106).click
      sleep 3 * GlobalAdjustedSleepTime
      widgetiv = Array.new
      divs.each do |d|
        widgetiv << d.text_field(:id,/#{$app.textWidgetTagId}/).text.to_s if d.id.to_s.match(/#{$app.divWidgetTagsId}/)
        sleep 0 + GlobalAdjustedSleepTime
      end
      site.widgets.each do |widgetSpace|
        widgetiv.each do |widgetTag|
          widgetSpace.tag = widgetTag if widgetTag.include?widgetSpace.name.gsub(/[\s]*/,'')
          widgetSpace.o_Id =  widgetSpace.tag.match(/sr_widget_id = (\d*)/)[1].to_s.strip if widgetSpace.tag
        end
      end
      $logger.info "Error There is  <#{site.widgets.length}> Widget Spaces and <#{widgetiv.length}> widget Tags" if widgetiv.length != site.widgets.length
    else
      $logger.info "Error  Site name <#{site.name}> was not found"
    end
    link(:id,/#{$app.linkDoneBtnId}/,2101).click
  end
  ### =============================================================================
  ### Collect all Conversion Tracking Tags from Network and assign them to campaigns
  ### =============================================================================
  def create_adspace(site, adSpace)
    sleep 2 * GlobalAdjustedSleepTime
    table1 = get_table_from_div($app.tableSiteMainId)
    my_row = find_row(table1, 'Site', site.name)
    my_row.cell(:class,/SiteActions/).links[0].click    ##em(:text, "Actions").click
    ## original   sleep 4 * GlobalAdjustedSleepTime
    #link(:xpath, "//td[3]/div/span/span/a/em").click
    sleep 4 * GlobalAdjustedSleepTime ## vvv  1
    puts "create ad space:  #{$app.linkCreateAdSpaceId}" ## vvv
    link(:id,/#{$app.linkCreateAdSpaceId}/,2195).click ## ,2195  
    ##link(:text, "Create new ad space").click   ## works vvv
    sleep 3
    ##element(:id, "ctl00_BodyContent_SiteActionButton_CreateAdSpace").click
    link(:id,/#{$app.linkCreateAdSpaceBtnId}/).click   ## original  link(:id,/#{$app.linkCreateAdSpaceBtnId}/).click
    sleep 1 * GlobalAdjustedSleepTime
    set_adspace_name(adSpace.name)
    set_adspace_description(adSpace.description)
    set_adspace_size(adSpace.size)
    set_adspace_domain(adSpace.domainName)
    set_adspace_page_position(adSpace.pagePosition)
    set_adspace_click_location(adSpace.openInNewWindow)
    set_adspace_third_party_url(adSpace.thirdPartyUrl)
    link(:id,/#{$app.linkSaveBtnId}/,2104).click
    sleep 2
    unless site.smart_tag
      adSpace.tag = text_field(:id,/#{$app.textAdTagId}/).value.to_s
      adSpace.o_Id = adSpace.tag.match(/sr_adspace_id = (\d*)/)[1].to_s.strip
      link(:id,/#{$app.linkDoneBtnId}/,2101).click
    else
      ## link(:text,"Back",2101).click
     ## link(:text, "Sites & Publishers").click
      link(:id,/topTabs_SitesTabDefault/).click
    end  
    $logger.info("Ad Space <#{adSpace.name}> has been added to site <#{site.name}>")
  end
  ### ============================================================================
  def fill_out_UpdateSignIn(person)
    text_field(:id,/#{$app.tNewPasswordId}/).set person.password
    text_field(:id,/#{$app.tConfirmPassId}/).set person.confirmPass
    checkbox(:id, /#{$app.cbPublisherTandId}/).set if person.accept
    link(:text, /#{$app.linkSaveBtnItext}/,102).click
    sleep 5 * GlobalAdjustedSleepTime
    $logger.info "Update Sign In page has been filled oud"
  end
  ### ============================================================================
  def set_report_params(report)
   ($logger.error("Unexpected page <#{$app.name}>") ;return) if $app.page_id != 4101
    select_list(:id,/#{$app.slReportTypeId}/).set /#{report.reportType}/
    if report.reportType.upcase.include?'PERFORMANCE'
      select_list(:id,/#{$app.slReportForId}/).select /#{report.reportFor}/
      select_list(:id,/#{$app.slShowDateRangeId}/).set report.showDays if report.showDays!= 0.to_s
      if report.fromDate.upcase != 'NA'
        ## select date func needed
        $logger.info "fill_out_Report::AdifyWatir select date func needed"
      end
      if report.toDate.upcase !=  'NA'
        ## select date func needed
        $logger.info "fill_out_Report::AdifyWatir select date func needed"
      end
    elsif report.type.upcase.include?'SEGMENT'
      $logger.info "fill_out_Report::AdifyWatir fill in fields for segment report"
    end
  end
  ### ============================================================================
  def getRowDataToHash(oTbl, col_name, text)
    return if not oTbl
    row1 = find_row(oTbl, col_name, text)
    if not row1
      $logger.testcase "Text #{text} column #{col_name} hasn't found in the report", 1
      return
    end
    out = Hash.new
    max = oTbl.column_count(1)-1
    for col in 0..max do
      key = oTbl.row_values(1)[col].to_s
      value = row1[col+1].to_s
      out[key] = value
    end
    return out
  end
  ### ============================================================================
  def get_active_div_by_pattern(pattern)
    3.times do
      divs.each do |dv|
        return dv if dv.attribute_value('id').to_s.include?(pattern) and dv.visible? ## dv.html.to_s.upcase.include?('LEFT')
      end
      wait 1
    end
  end
  ### ============================================================================
  def create_net(nb)
   ($logger.error("Unexpected page <#{$app.name}>") ;return) unless $app.kind_of?AdifyPlatformTool
    link(:id,/#{$app.linkSearchID}/,9200).click
#    span(:id=>/topTabs_ToolsSubTab/).hover
#    sleep 1
    span(:id=>/topTabs_ToolsSubTab/).click
    sleep 2
    link(:id,/#{$app.linkCreateNBID}/,9401).click
    fill_out_nb_account nb
    link(:id, /#{$app.linkbtCreateNBID}/,9402).click
    nb.primeUID = getSpanValue $app.spanUid
    if text.include?nb.name
      $logger.testcase("Create new network builder<#{nb.name}>, user ID<#{nb.primeUID}>",0)
    else
      $logger.testcase("Create new network builder<#{nb.name}>, user ID<#{nb.primeUID}>",1)
    end
    link(:id, /#{$app.linkCreateNetwork}/, 9403).click
    fill_out_NetDetails nb
    link(:id,/#{$app.linkSaveBtn}/,1101).click
    if span(:id,/#{$app.spanNetworkNameId}/).text == nb.networkName
      $logger.testcase("Create new network <#{nb.networkName}>",0)
    else
      $logger.testcase("Create new network <#{nb.networkName}>",1)
    end
    ### getting network id
    link(:text, /#{$app.linkAManagementItext}/,7001).click
    sleep 5 * GlobalAdjustedSleepTime
    nb.network_Id = span(:id,/#{$app.divNetworkIDValId}/).attribute_value("innerText")
    link(:text, /#{$app.linkNetworkItext}/,1101).click
  end
  ### =============================================================================
  def create_net_builder(nb)
   ($logger.error("Unexpected page <#{$app.name}>") ;return) unless $app.kind_of?AdifyPlatformTool
    link(:id,/#{$app.linkSearchID}/,9200).click
    link(:id,/#{$app.linkCreateNBID}/,9401).click
    fill_out_nb_account nb
    link(:id, /#{$app.linkbtCreateNBID}/,9402).click
    nb.primeUID = getSpanValue $app.spanUid
    if text.include?nb.name
      $logger.testcase("Create new network builder<#{nb.name}>, user ID<#{nb.primeUID}>",0)
    else
      $logger.testcase("Create new network builder<#{nb.name}>, user ID<#{nb.primeUID}>",1)
    end
    link(:id, /#{$app.linkCreateNetwork}/, 9403).click
    fill_out_NetDetails nb
    link(:id,/#{$app.linkSaveBtn}/,1101).click
    if span(:id,/#{$app.spanNetworkNameId}/).text == nb.networkName
      $logger.testcase("Create new network <#{nb.networkName}>",0)
    else
      $logger.testcase("Create new network <#{nb.networkName}>",1)
    end
  end
  ### =============================================================================
  def impersonate_net_by_name(nBuilder)
   ($logger.error("Unexpected page <#{$app.name}>") ;return) unless $app.kind_of?AdifyPlatformTool
   ##  if $PERF
      ## now = Time.now.to_f
      #if $COXAUTO == true
       # nBuilder = @net_builder3
      #else 
       # nBuilder = @net_builder1
      #end
      span(:id,/RecentNetworkLinks_title/).click  ##  ctl00_ctl00_ctl00_ctl00_RecentNetworkLinks_title   ##  vvv
      sleep 1
      link(:id,/RecentNetworkLinks_LinkSelectNetwork/).click  ## ctl00_ctl00_ctl00_ctl00_RecentNetworkLinks_LinkSelectNetwork
      sleep 1
      if text_field(:id,"AllNetworksGridSearchText").exists?
       text_field(:id,"AllNetworksGridSearchText").set nBuilder.network_Id.to_s  ## cds connect >> "2000100008990"   ## cds >>"1340910"   
      end
      ## => text_field(:id,"AllNetworksGridSearchText").set nBuilder.networkName   if nBuilder.network_Id == ""
      sleep 1
      button(:id, /#{$app.btnSearchNetworkID}/).click  ## ctl00_ctl00_ctl00_ctl00_SelectAllNetworksDialog_AllNetworksGridSearchButton
      sleep 3
      ## radio(:id, "rb_2000100008990").set  # cds connect   vvv
      ## radio(:id, "rb_1340910").set  #  cox
      radio(:id, "rb_" + nBuilder.network_Id.to_s).set ## vvv
      sleep 4
      link(:id,/#{$app.linkSelectNetworkOKBtnID}/,9403).click ##  "ctl00_ctl00_ctl00_ctl00_SelectAllNetworksDialog_OK"
      ## endd = Time.now.to_f
      ## puts "new time in secs: #{endd - now}"
 ## else
    ## now = Time.now.to_f
    ## span(:id,/RecentNetworkLinks_title/).click
    ## link(:id,/#{$app.linkSelectNetworkID}/).click
    ## sleep 10 * GlobalAdjustedSleepTime
    ##   ## sleep 4 if text_field(:id,/#{$app.tSelectNetworkID}/).disabled
    ## sleep 4 unless text_field(:id,/#{$app.tSelectNetworkID}/).exists?   # vvv  
    ## text_field(:id,/#{$app.tSelectNetworkID}/).set nBuilder.network_Id.to_s unless nBuilder.network_Id == ""
    ## text_field(:id,/#{$app.tSelectNetworkID}/).set nBuilder.networkName   if nBuilder.network_Id == ""
    ## button(:id,/#{$app.btnSearchNetworkID}/).click
    ## sleep 4 * GlobalAdjustedSleepTime
    ## radio(:id, /rb_#{nBuilder.network_Id}/).set
    ## link(:id,/#{$app.linkSelectNetworkOKBtnID}/,9403).click   #ctl00_ctl00_ctl00_ctl00_SelectAllNetworksDialog_OK
       ## endd = Time.now.to_f
       ## puts "old time in secs: #{endd - now}"
    ## end 
  end
  ### =============================================================================
  def add_partner_nets(nb)
   ($logger.error("Unexpected page <#{$app.name}>") ;return) unless $app.kind_of?NetworkCS
    sleep 7 * GlobalAdjustedSleepTime
    link(:text,/#{$app.linkAManagementItext}/,7001).click
    radio(:id,/#{$app.rbPartNetCustomId}/).set
    sleep 2 * GlobalAdjustedSleepTime
    nb.partnerNetworksList.each {|nbl|
      link(:id,/#{$app.linkEditPartnerNetworksId}/).click
      sleep 30 * GlobalAdjustedSleepTime
      checkbox(:id,/#{$app.cbPartnerNetworksAllId}/).set
      checkbox(:id,/#{$app.cbPartnerNetworksAllId}/).clear
      text_field(:id,/#{$app.tPartnersearchId}/).set nbl.network_Id.to_s    if nbl.network_Id != ""
      text_field(:id,/#{$app.tPartnersearchId}/).set nbl.networkName        if nbl.network_Id == ""
      button(:id,/#{$app.btnPartnersearchId}/).click
      sleep 3 * GlobalAdjustedSleepTime
      checkbox(:id,/#{$app.cbPartnerNetworksGridId}/).set if checkbox(:id,/#{$app.cbPartnerNetworksGridId}/).exists?
      $logger.info("Fail to find partner network #{nbl.networkName}") unless checkbox(:id,/#{$app.cbPartnerNetworksGridId}/).exists?
      link(:id,/#{$app.linkOKPartnDialogId}/).click
    }
    link(:id,/#{$app.linkSaveButtonId}/).click
  end
  ### =============================================================================
  def create_publisher(pub)
 ##>>  ($logger.error("Unexpected page object <#{$app.name}>"); return) unless $app.kind_of?NetworkCS   # original
    if not text_field(:id, "ctl00_BodyContent_nameTextBox")      # vvv new       
    ($logger.info("Unexpected page object <#{$app.name}>"); return) unless $app.kind_of?NetworkCS   
    else
    div(:id => "ctl00_appHeader_topTabs_ctl00").link(:text,"Sites").click  # vvv new    ctl00_appHeader_topTabs_ctl00    $SITESTABID
    ##link(:text,/#{$app.linkSitesItext}/,2101).click   ## original
    link(:id,"ctl00_appHeader_topTabs_AccountsTab").click
    link(:id,"ctl00_BodyContent_CreatePublisherButton",8200).click
#    ctl00_appHeader_topTabs_AccountsTab
#    link(:text,/#{$app.linkCreatePubItext}/,2102).click
    fill_out_pubAccount pub
    sleep 3 * GlobalAdjustedSleepTime
#    link(:text,/#{$app.linkCreatePubaccountItext}/,2101).click
    link(:id,"ctl00_ctl00_BodyContent_BodyContent_SignUpButton").click
    sleep 3 * GlobalAdjustedSleepTime
   ## if link(:text,/Sites & Publishers/).exists?
   end
    if text.include?"Publishers and Rep Agencies"
      $logger.testcase("Create new publisher Publisher <#{pub.name}>  has been created",0)
    else
      $logger.testcase("Create new publisher Publisher <#{pub.name}>  hasn't been created",1)
    end
  end
  def look_up_pub_on_site_and_pub_page(pub)
    $logger.info("Looking up a publisher <#{pub.name}> by Site&Publisher name")
    link(:id,"ctl00_appHeader_topTabs_AccountsTab").click
    sleep 1
    text_field(:id,/PublishersandRepsSearchTextbox/).set pub.name
    button(:id,/PublishersAndRepsButton/).click
    sleep 5
    # 30.times{ break if link(:text,/#{pub.name}/).exists?; sleep 1  * GlobalAdjustedSleepTime}
    60.times{ break if text.include?pub.name; sleep 1  * GlobalAdjustedSleepTime}
    sleep 0
   end
  ### =============================================================================
     def look_up_site_on_site_page(site)
    $logger.info("Looking up a site <#{site.name}> by name")
    link(:id,/appHeader_topTabs_AccountsTab/).click #<a id="ctl00_ctl00_appHeader_topTabs_AccountsTab" href="Accounts.aspx">Accounts</a>
    sleep 1
    link(:id,/appHeader_topTabs_SitesTabDefault/).click
    sleep 1
    text_field(:id,/SiteTableSearchBox/).set site.name.split(" ").last
    button(:id,/SiteTableSearchButton/).click
    sleep 5
    # 30.times{ break if link(:text,/#{pub.name}/).exists?; sleep 1  * GlobalAdjustedSleepTime}
    60.times{ break if text.include?site.name; sleep 1  * GlobalAdjustedSleepTime}
    sleep 0
   end
  ### =============================================================================
  def set_pub_approval_status(pub, option_status = 'Approved')
    $logger.info("Setting up publisher's approval status <#{pub.name}>")
    look_up_pub_on_site_and_pub_page(pub)
#    links(:text,/#{pub.name}/).first.click
    table1 = get_table_from_div(/BodyContent_AccountsTable/)
    30.times{ break if div(:id,/BodyContent_AccountsTable/).exists?; sleep 2 * GlobalAdjustedSleepTime}
    my_row = find_row(table1, "User name", pub.name)
    link_publisher_action = my_row.as.collect{|link| link if link.text.downcase == "actions"}.compact[-1]
    link_publisher_action.click
    link(:id,"ctl00_BodyContent_ActionButton_EditAccount",2103).click  ## vvv  campaign
    ##link(:text,/Edit Account/,2103).click
    sleep 1
#    link(:text,/Account/,2103).click
#    sleep 1
    select_list(:id,/DropDownListPublisherApprovalStatus/).select(option_status)
    sleep 3
    link(:text,/#{$app.linkSitesItext}/,2101).click
  end
  ### =============================================================================
  def delete_all_publishers
   ($logger.error("Unexpected page <#{$app.name}>"); return) unless $app.kind_of?NetworkCS
    link(:text,/#{$app.linkSitesItext}/,2101).click
    ## row_pub = div(:id,/SiteTable/).tables[0].rows[3]
    tbl =  get_table_from_div("SiteTable")
    while tbl.rows.length > 2
      tbl.rows[2].cell(:class,/UserActions/).link(:text,/Actions/).click
      link(:id,/UserRemovePublisher/).click
      sleep 1 * GlobalAdjustedSleepTime
      link(:id,/#{$app.linkConfirmRemovePubId}/).click if link(:id,/#{$app.linkConfirmRemovePubId}/).exists?
      sleep 1 * GlobalAdjustedSleepTime
      tbl =  get_table_from_div("SiteTable")
      sleep 1 * GlobalAdjustedSleepTime
    end
    sleep 1 * GlobalAdjustedSleepTime
  end
  ### =============================================================================
  def add_site(site)
   ($logger.error("Unexpected page <#{$app.name}>"); return) unless $app.kind_of?SitesAndPubNB
    link(:text,/#{$app.linkActionDropDowntext}/).click
    sleep 2 * GlobalAdjustedSleepTime
    link(:id,/#{$app.linkAddNewSiteId}/,2103).click
 #   fill_out_create_site_new(site) if (@@env.downcase == "qa" or @@env.downcase == "staging")
    fill_out_create_site(site) #unless (@@env.downcase == "qa" or @@env.downcase == "staging")
    link(:text,/Save/,2103).click
    link(:id,/#{$app.linkSavePopUpId}/,2101).click if link(:id,/#{$app.linkSavePopUpId}/).exists?
    sleep 7 * GlobalAdjustedSleepTime
    if text.include?"Sites & Publishers"
      $logger.testcase("New Site <#{site.name}>  has been created",0)
      site.adSpaces.each {|adspc|
        create_adspace(site,adspc) unless adspc.default 
        sleep 1 * GlobalAdjustedSleepTime
      }
      get_ad_tags(site)
    else
      $logger.error("Site <#{site.name}>and ad spaces hasn't been created")
    end
  end
  ## =============================================================================
  def get_action_link(row,index)
    link_publisher_action = (row.links.collect do |link|
      link if link.document.invoke( "innerText").downcase == "actions"
      end).compact! ## here we find Action link for publisher
      return link_publisher_action[index-1]
    end
    ### =============================================================================
    def create_site(publ,site)
      sleep 2 * GlobalAdjustedSleepTime
       ($logger.error("Unexpected page <#{$app.name}>"); return) unless $app.kind_of?SitesAndPubNB
      link(:id,/topTabs_SitesTabDefault/).click
      sleep 0.5
      link(:id,/CreateSiteButton/).click
      sleep 0.5
      link(:id,/selectPublisherButton/).click
      sleep 2
      text_field(:id,/selectPublisherSearchText/).set (publ.name + publ.lastName)
      input(:id,/selectPublisherSearchButton/).click
      sleep 0.5
      radio(:id, /rb_/).set  
      link(:id,/SelectPublisherDialog_OK/).click
      sleep 0.5
      text_field(:id,/siteNameValue/).set site.name
      text_field(:id,/siteURLValue/).set site.url
      text_field(:id,/siteDescriptionValue/).set site.description
      fill_out_create_site(site) if site.inventory_type.upcase == "NATIONAL"   ## unless  (@@env.downcase == "qa" or @@env.downcase == "staging")
      fill_out_local_site(site) if site.inventory_type.upcase == "LOCAL"
      sleep 1 * GlobalAdjustedSleepTime
      link(:id,/setPayoutAndSaveButton/,2103).click
      link(:id,/#{$app.linkSavePopUpId}/,2101).click if link(:id,/#{$app.linkSavePopUpId}/).exists?
      sleep 2 * GlobalAdjustedSleepTime
      if text.include?"Sites"
        $logger.testcase("New Site <#{site.name}>  has been created",0)
        site.adSpaces.each {|adspc|
          sleep 3
          unless adspc.default
            look_up_site_on_site_page(site)
 #           look_up_pub_on_site_and_pub_page(site.publisher)
            create_adspace(site,adspc) 
          end
        }
        sleep 5 * GlobalAdjustedSleepTime
        look_up_site_on_site_page(site)
        if site.smart_tag == "true"
          get_smart_ad_tags(site)
        else
          get_ad_tags(site) if site.name
        end
      else
        $logger.testcase("Site <#{site.name}>  hasn't been created",1)
      end
    end
    ### =============================================================================
    def get_displayed_div(oId)
      i=0
      while div(:id,/#{oId}#{i.to_s}/).exists?
        out_div = div(:id,/#{oId}#{i.to_s}/) if div(:id,/#{oId}#{i.to_s}/).style.invoke('display') != "none"
        i +=1
      end
      return out_div
    end
    ### =============================================================================
    def add_tag_to_sites(nb,tag)
      link(:id,/#{$app.btnCreateSiteTagId}/).click
      sleep 2 * GlobalAdjustedSleepTime
      span(:text,/#{$app.spanEnterTagItext}/).click
      sleep 3 * GlobalAdjustedSleepTime
      div1 = get_displayed_div($app.divTagSitesId)
      div1.text_fields[0].set tag.name
      div1.button(:text,/#{$app.btnSaveItext}/).click
      if div(:id,/TagErrorMessageBox_dlg_c/).style.invoke('visibility') == "visible"   ## link(:id,/#{$app.linkErrorOkId}/).exists?
        link(:id,/#{$app.linkErrorOkId}/).click                                        ## in case tag has been created early
        text_field(:id,/#{$app.tSiteSearchId}/).set tag.name
        button(:id,/#{$app.btnSiteSearchId}/).click
      end
      sites_to_tag = []
      tag.assigned_bo_names.each {|bo_name|
        Site.instances.each { |site|
          sites_to_tag<<site if site.bo_name == bo_name
        sites_to_tag -= [nil]
      }
    }
    sleep 3 * GlobalAdjustedSleepTime
    tbl = div(:id,/#{$app.divSiteMainTableId}/).tables[0]
    row =  find_row(tbl, "Tag", tag.name)
    sites_to_tag.each {|s|
      ($logger.error("Unexpected page <#{$app.name}>"); break ) if row.nil?
      row.links[0].click
      sleep 2 * GlobalAdjustedSleepTime
      text_field(:id,/#{$app.tListSearchId}/).set s.name ### set name or id
      button(:id,/#{$app.btnListSearchId}/).click
      sleep 2 * GlobalAdjustedSleepTime
      if checkbox(:id,/#{$app.cbSelectSiteId}/).exists? #{s.site_Id}
        checkbox(:id,/#{$app.cbSelectSiteId}/).set
        link(:id,/#{$app.linkSaveId}/).click            #{s.site_Id}
      else
        link(:id,/#{$app.linkCancelId}/).click
        $logger.info("Fail to find site <#{s.name}> and assign it to tag <#{tag.name}>")
      end
      sleep 2 * GlobalAdjustedSleepTime
    }
    refresh
  end
  ### ============================================================================
  def add_tag_to_adspaces(nb,tag)
    div(:id,/#{$app.divTabViewId}/).link(:text,/#{$app.linkAdSpacesTabItext}/).click
    link(:id,/#{$app.btnCreateAdSpaceTagId}/).click
    sleep 2 * GlobalAdjustedSleepTime
    span(:text,/#{$app.spanEnterTagItext}/).click
    sleep 2 * GlobalAdjustedSleepTime
    div1 = get_displayed_div($app.divTagAdSpaceId)
    div1.text_fields[0].set tag.name
    div1.button(:text,/#{$app.btnSaveItext}/).click
    if div(:id,/TagErrorMessageBox_dlg_c/).style.invoke('visibility') == "visible"
      link(:id,/#{$app.linkErrorOkId}/).click   ## in case tag has been created early
      text_field(:id,/#{$app.tAdSpaceSearchId}/).set tag.name
      button(:id,/#{$app.btnAdSpaceSearchId}/).click
    end
    adspaces_to_tag = []
    tag.assigned_bo_names.each {|bo_name|
      AdSpace.instances.each { |ad_space|
        adspaces_to_tag<<ad_space if ad_space.bo_name == bo_name
        adspaces_to_tag -= [nil]
      }
    }
    sleep 4 * GlobalAdjustedSleepTime
    tbl = div(:id,/#{$app.divAdSpMainTableId}/).tables[0]
    row =  find_row(tbl, "Tag", tag.name)
    adspaces_to_tag.each {|s|
      row.links[0].click
      sleep 2 * GlobalAdjustedSleepTime
      text_field(:id,/#{$app.tListSearchId}/).set s.name
      button(:id,/#{$app.btnListSearchId}/).click
      sleep 5 * GlobalAdjustedSleepTime
      if checkbox(:id,/#{$app.cbSelectAdSpaceId}/).exists?
        checkbox(:id,/#{$app.cbSelectAdSpaceId}/).set
        link(:id,/#{$app.linkSaveId}/).click
      else
        $logger.info("Fail to find AdSpace <#{s.name}> and assign it to tag <#{tag.name}>")
      end
      sleep 3 * GlobalAdjustedSleepTime
    }
  end
  ### ============================================================================
  def add_tag_to_net(nb,tag)
    div(:id,/#{$app.divTabViewId}/).link(:text,/#{$app.linkNetworksTabItext}/).click
    link(:id,/#{$app.btnCreateNetworkTagId}/).click
    sleep 2 * GlobalAdjustedSleepTime
    span(:text,/#{$app.spanEnterTagItext}/).click
    sleep 2 * GlobalAdjustedSleepTime
    div1 = get_displayed_div($app.divTagNetId)
    div1.text_field[0].set tag.name
    div1.button(:text,/#{$app.btnSaveItext}/).click
    if div(:id,/TagErrorMessageBox_dlg_c/).style.invoke('visibility') == "visible"
      link(:id,/#{$app.linkErrorOkId}/).click                  ## in case the tag was created earlier
      text_field(:id,/#{$app.tNetworkSearchId}/).set tag.name
      button(:id,/#{$app.btnNetworkSearchId}/).click
    end
    nets_to_tag = []
    tag.assigned_bo_names.each {|bo_name|
      NetBuilder.instances.each { |netbuilder|
        nets_to_tag << netbuilder if netbuilder.bo_name == bo_name
        nets_to_tag -= [nil]
      }
    }
    sleep 7  * GlobalAdjustedSleepTime
    tbl = get_table_from_div($app.divNetMainTableId)
    row =  find_row(tbl, "Tag", tag.name)
    nets_to_tag.each {|s|
      row.links[0].click
      sleep 5  * GlobalAdjustedSleepTime
      text_field(:id,/#{$app.tListSearchId}/).set s.network_Id     if s.network_Id != "" ### set id
      text_field(:id,/#{$app.tListSearchId}/).set s.networkName    if s.network_Id == "" ### set name
      button(:id,/#{$app.btnListSearchId}/).click
      sleep 5  * GlobalAdjustedSleepTime
      if checkbox(:id,/#{$app.cbSelectNetId}/).exists?
        checkbox(:id,/#{$app.cbSelectNetId}/).set
        link(:id,/#{$app.linkSaveId}/).click
      else
        $logger.info("Fail to find Net <#{s}> and assign it to tag <#{tag.name}>")
        link(:id,/#{$app.linkCancelId}/).click
      end
    }
  end
  ### ============================================================================
  def delete_all_tags_or_bundles_for_network
    delete_all_tags_or_bundles
    div(:id,/#{$app.divTabViewId}/).link(:text,/#{$app.linkAdSpacesTabItext}/).click
    delete_all_tags_or_bundles
    div(:id,/#{$app.divTabViewId}/).link(:text,/#{$app.linkNetworksTabItext}/).click
    delete_all_tags_or_bundles
    ($logger.info("Wrong Page #{$app.name}"); return) unless $app.kind_of?EditTags
    link(:id,/#{$app.linkEditTagBundlId}/,1302).click
    button(:id,/#{$app.btnBundleSearchId}/).click
    delete_all_tags_or_bundles
    link(:text,/#{$app.linkSitesItext}/,2101).click
    link(:id,/#{$app.linkEditTagsId}/,1301).click
  end
  ### ============================================================================
  def delete_all_tags_or_bundles
    ($logger.info("Wrong Page #{$app.name}"); return) unless $app.kind_of?EditTags
    while span(:title => /delete Bundle_1/).exists?
      span(:title => /delete Bundle_1/).click
      sleep 1  * GlobalAdjustedSleepTime
      link(:id,/DeleteTag/).click if link(:id,/DeleteTag/).exists?
      sleep 1  * GlobalAdjustedSleepTime
    end
  end
  ### ============================================================================
  def create_bundle(nb,bndl)
    ($logger.info("Wrong Page #{$app.name}"); return) unless $app.kind_of?EditTags
    link(:id,/#{$app.linkEditTagBundlId}/,1302).click
    button(:id,/#{$app.btnBundleSearchId}/).click
    unless text.include?bndl.name
      link(:id,/#{$app.linkCreateTagBundleId}/).click
      sleep 1  * GlobalAdjustedSleepTime
      span(:text,/#{$app.spanEnterBndlItext}/).click
      sleep 2  * GlobalAdjustedSleepTime
      div1 = get_displayed_div($app.divBundleId)
      div1.text_fields[0].set bndl.name
      div1.button(:text,/#{$app.btnSaveItext}/).click
    end
    tags_to_bndl = []
    bndl.assigned_bo_names.each {|bo_name|
      Tag.instances.each{|tag|
        tags_to_bndl<<tag if tag.bo_name.strip == bo_name.strip and not tags_to_bndl.include?tag
        tags_to_bndl -= [nil]
      }
    }
    ## tbl = get_bundles_table
    tbl = get_table_from_div($app.divBndlMainTableId)
    row =  find_row(tbl, "Tag bundle", bndl.name)
    ## deselect all old tags
    row.links[0].click
    button(:id,/#{$app.btnBndlSearchId}/).click
    checkbox(:id,/#{$app.cbSelectAllId}/).set
    checkbox(:id,/#{$app.cbSelectAllId}/).clear
    link(:id,/#{$app.linkSaveId}/).click
    tags_to_bndl.each {|s|
      row.links[0].click
      sleep 7  * GlobalAdjustedSleepTime
      text_field(:id,/#{$app.tBndlSearchId}/).set s.name if text_field(:id,/#{$app.tBndlSearchId}/).exists? ### set name or id
      button(:id,/#{$app.btnBndlSearchId}/).click
      if checkbox(:id,/#{$app.cbSelectBndlId}/).exists?
        checkbox(:id,/#{$app.cbSelectBndlId}/).set
        link(:id,/#{$app.linkSaveId}/).click
      else
        $logger.info("Fail to find tag <#{s.name}> ")
        link(:id,/#{$app.linkCancelId}/).click
      end
    }
    link(:id,/#{$app.linkEditTagsId}/,1301).click
  end
  ### ============================================================================
  def assign_tags(nb)
    (puts "Wrong Page method:<assign_tags> net:<#{nb.networkName}>"; return) unless $app.kind_of?NetworkCS
    link(:text,/#{$app.linkSitesItext}/,2101).click
    link(:id,/#{$app.linkEditTagsId}/,1301).click
    ### delete_all_tags_or_bundles_for_network  ## to do: debug this method first
    nb.tags.each {|t| add_tag_to_sites(nb,t)    if t.type.to_s.downcase == "site"   }
    nb.tags.each {|t| add_tag_to_adspaces(nb,t) if t.type.downcase      == "adspace"}
  #  nb.tags.each {|t| add_tag_to_net(nb,t)      if t.type.downcase      == "net"    }
  #  nb.tags.each {|t| create_bundle(nb,t)       if t.type.downcase      == "bundle" }
    link(:text,/#{$app.linkSitesItext}/,2101).click
  end
  ### ============================================================================
  def rename_tag(tag,new_name)
    ($logger.error "Wrong Page method:<assign_tags> net:<#{nb.networkName}>"; return) unless $app.kind_of?NetworkCS
    link(:text,/#{$app.linkSitesItext}/,2101).click
    link(:id,/#{$app.linkEditTagsId}/,1301).click
    rename_site_tag(tag,new_name)    if tag.type.to_s.downcase == "site"
    rename_adspace_tag(tag,new_name) if tag.type.downcase      == "adspace"
    rename_net_tag(tag,new_name)     if tag.type.downcase      == "net"
    rename_bundle(tag,new_name)      if tag.type.downcase      == "bundle"
    link(:text,/#{$app.linkSitesItext}/,2101).click
  end
  ### ============================================================================
  def delete_obj_from_tag(tag,obj)
    ($logger.error "Input Tag obj error:<#{tag.kind_of?}>"; return)   unless tag.kind_of?Tag
    ($logger.error "Unexpected page :<#{$app.kind_of?}>"; return)          unless $app.kind_of?NetworkCS
    link(:text,/#{$app.linkSitesItext}/,2101).click
    link(:id,/#{$app.linkEditTagsId}/,1301).click
    delete_site_from_tag(tag,obj)    if tag.type.to_s.downcase == "site"
    delete_adspace_from_tag(tag,obj) if tag.type.downcase      == "adspace"
    delete_net_from_tag(tag,obj)     if tag.type.downcase      == "net"
    ## rename_bundle(tag,text)      if tag.type.downcase      == "bundle"
    link(:text,/#{$app.linkSitesItext}/,2101).click
  end
  ### ============================================================================
  def delete_site_from_tag(tag,s)
    ($logger.error "Input Site obj error:<#{s.class}>"; return)   unless s and s.kind_of?Site
    div(:id,/#{$app.divTabViewId}/).link(:text,/#{$app.linkSitesTabItext}/).click
    text_field(:id,/#{$app.tSiteSearchId}/).set tag.name
    button(:id,/#{$app.btnSiteSearchId}/).click
    sleep 2  * GlobalAdjustedSleepTime
    tbl = div(:id,/#{$app.divSiteMainTableId}/).tables[0]
    row =  find_row(tbl, "Tag", tag.name)
    ($logger.error("Tag <#{tag.name}> was not found and deleted"); return) unless row
    row.links[0].click
    text_field(:id,/#{$app.tListSearchId}/).set s.name ### set name or id
    button(:id,/#{$app.btnListSearchId}/).click
    sleep 2  * GlobalAdjustedSleepTime
    if checkbox(:id,/#{$app.cbSelectSiteId}/).exists? #{s.site_Id}
      checkbox(:id,/#{$app.cbSelectSiteId}/).clear
      link(:id,/#{$app.linkSaveId}/).click      #{s.site_Id}
    else
      link(:id,/#{$app.linkCancelId}/).click
      $logger.info("Fail to find site <#{s.name}> and delete it from tag <#{tag.name}>")
    end
    sleep 2  * GlobalAdjustedSleepTime
    refresh
  end
  ### ============================================================================
  def delete_adspace_from_tag(tag,as)
    ($logger.error "Input AdSpace obj error:<#{as.class}>"; return)   unless as and as.kind_of?AdSpace
    div(:id,/#{$app.divTabViewId}/).link(:text,/#{$app.linkAdSpacesTabItext}/).click
    text_field(:id,/#{$app.tAdSpaceSearchId}/).set tag.name
    button(:id,/#{$app.btnAdSpaceSearchId}/).click
    tbl = div(:id,/#{$app.divAdSpMainTableId}/).tables[0]
    row =  find_row(tbl, "Tag", tag.name)
    ($logger.error("Tag <#{tag.name}> was not found and deleted"); return) unless row
    row.links[0].click
    text_field(:id,/#{$app.tListSearchId}/).set as.name
    button(:id,/#{$app.btnListSearchId}/).click
    sleep 3  * GlobalAdjustedSleepTime
    if checkbox(:id,/#{$app.cbSelectAdSpaceId}/).exists?
      checkbox(:id,/#{$app.cbSelectAdSpaceId}/).clear
      link(:id,/#{$app.linkSaveId}/).click
    else
      $logger.info("Fail to find AdSpace <#{as.name}> and delete it from tag <#{tag.name}>")
    end
    sleep 3  * GlobalAdjustedSleepTime
  end
  ### ============================================================================
  def delete_net_from_tag(tag,net)
    ($logger.error "Input NetBuilder obj error:<#{net.class}>"; return)   unless net and net.kind_of?AdSpace
    div(:id,/#{$app.divTabViewId}/).link(:text,/#{$app.linkNetworksTabItext}/).click
    text_field(:id,/#{$app.tNetworkSearchId}/).set tag.name
    button(:id,/#{$app.btnNetworkSearchId}/).click
    tbl = div(:id,/#{$app.divNetMainTableId}/).tables[0]
    row =  find_row(tbl, "Tag", tag.name)
    ($logger.error("Tag <#{tag.name}> was not found and deleted"); return) unless row
    row.links[0].click
    text_field(:id,/#{$app.tListSearchId}/).set s.network_Id     if net.network_Id != "" ### set name or id
    text_field(:id,/#{$app.tListSearchId}/).set s.networkName    if net.network_Id == ""
    button(:id,/#{$app.btnListSearchId}/).click
    sleep 3  * GlobalAdjustedSleepTime
    if checkbox(:id,/#{$app.cbSelectNetId}/).exists?
      checkbox(:id,/#{$app.cbSelectNetId}/).clear
      link(:id,/#{$app.linkSaveId}/).click
    else
      $logger.info("Fail to find Net <#{net.networkName}> and delete it from tag <#{tag.name}>")
      link(:id,/#{$app.linkCancelId}/).click
    end
  end
  ### ============================================================================
  def rename_site_tag(tag,text)
    div(:id,/#{$app.divTabViewId}/).link(:text,/#{$app.linkSitesTabItext}/).click
    text_field(:id,/#{$app.tSiteSearchId}/).set tag.name
    button(:id,/#{$app.btnSiteSearchId}/).click
    sleep 1  * GlobalAdjustedSleepTime
    tbl = div(:id,/#{$app.divSiteMainTableId}/).tables[0]
    row =  find_row(tbl, "Tag", tag.name)
    ($logger.error("Tag <#{tag.name}> was not found and renamed"); return) unless row
    row.div(:text,/#{tag.name}/).click
    div1 = get_displayed_div("textboxceditor")
    div1.text_fields[0].set text
    div1.button(:text,/#{$app.btnSaveItext}/).click
    refresh
  end
  ### ============================================================================
  def rename_adspace_tag(tag,text)
    div(:id,/#{$app.divTabViewId}/).link(:text,/#{$app.linkAdSpacesTabItext}/).click
    text_field(:id,/#{$app.tAdSpaceSearchId}/).set tag.name
    button(:id,/#{$app.btnAdSpaceSearchId}/).click
    sleep 1  * GlobalAdjustedSleepTime
    tbl = div(:id,/#{$app.divAdSpMainTableId}/).tables[0]
    row =  find_row(tbl, "Tag", tag.name)
    ($logger.error("Tag <#{tag.name}> was not found and renamed"); return) unless row
    row.div(:text,/#{tag.name}/).click
    div1 = get_displayed_div("textboxceditor")
    div1.text_fields[0].set text
    div1.button(:text,/#{$app.btnSaveItext}/).click
    refresh
  end
  ### ============================================================================
  def rename_net_tag(tag,text)
    div(:id,/#{$app.divTabViewId}/).link(:text,/#{$app.linkNetworksTabItext}/).click
    text_field(:id,/#{$app.tNetworkSearchId}/).set tag.name
    button(:id,/#{$app.btnNetworkSearchId}/).click
    sleep 1  * GlobalAdjustedSleepTime
    tbl = div(:id,/#{$app.divNetMainTableId}/).tables[0]
    row =  find_row(tbl, "Tag", tag.name)
    ($logger.error("Tag <#{tag.name}> was not found and renamed"); return) unless row
    row.div(:text,/#{tag.name}/).click
    div1 = get_displayed_div("textboxceditor")
    div1.text_fields[0].set text
    div1.button(:text,/#{$app.btnSaveItext}/).click
    refresh
  end
  ### ============================================================================
  def creative_is_on_page?(ads = []) ## watir method
    ads.each {|ad|
      ($logger.error"Wrong object Expected class Ad Actual <#{ad.class}>"; return nil) unless (ad.kind_of?Ad or ad.kind_of?Feed) #check ad type..
      case ad.type.upcase
      when  /HTML/
        return true if self.text.include?(ad.code[0,20].to_s)#Reduced to 20 characters to work with Feed.code
      when "FLASH"
        # get flash's url from ie object
        url =self.element_by_xpath("//*[@id='flashObject']").altHtml.sub(/^.*name="flashObject" src="http:../, '').sub(/swf.*$/, 'swf')
        if ad.file ==''
          return true if ad.sourceURL.sub(/^http.../, '') == url
          #(Net::HTTP.new(URI.parse(ad.sourceURL).host).get(URI.parse(ad.sourceURL).path).response['Content-Length']  == Net::HTTP.new(url.sub(/net.*$/, 'net')).get(url.sub(/^.*net/, '')).response['Content-Length'])
        else
          return true if (Net::HTTP.new(url.sub(/net.*$/, 'net')).get(url.sub(/^.*net/, '')).response['Content-Length']  == File.size?(ad.file).to_s)
        end
      when  "RSS"
        return true if self.html.include?(URI.parse(ad.sourceURL).host)#Reduced to 20 characters to work with Feed.code
      when "IFRAME"
        return true if self.frame(:src, ad.sourceURL)
      when "IMAGE"
        self.images.each do |image|
          return true  if (image.fileSize == ad.file)
        end
        self.links.each do |link|
          (return true) if link.href.include?(ad.destinationURL)
        end
      end
    }
    return false
  end
  ### ============================================================================
  def create_widget(widget)
    link(:text,/#{$app.linkSitesItext}/, 220).click unless ($app.kind_of?SitesAndPubNB or $app.kind_of?WidgetDashboard)
    sleep 2  * GlobalAdjustedSleepTime
    link(:id,/#{$app.linkWidDashID}/, 2301).click        unless $app.kind_of?WidgetDashboard
    ($logger.error "Unexpected page :<#{$app.name}>"; return)     unless $app.kind_of?WidgetDashboard
    $logger.info "Creating Widget  <#{widget.name}>"
    if link(:id,/#{$app.linkCreateNewWidgetId}/).exists?
      link(:id,/#{$app.linkCreateNewWidgetId}/,2302).click
    else
      link(:text,'Create a new widget',2302).click
    end
    text_field(:id,/#{$app.tWidgetNameId}/).set widget.name
    text_field(:id,/#{$app.tWidgetDescriptionId}/).set widget.widgetDescription
    case widget.type.upcase
    when  "HTML"
      select_list(:id,/#{$app.slWidgetTypeId}/).select 'HTML / JavaScript'
    when "FLASH"
      select_list(:id,/#{$app.slWidgetTypeId}/).select 'Flash'
    when  "RSS"
      select_list(:id,/#{$app.slWidgetTypeId}/).select 'RSS'
      sleep 1  * GlobalAdjustedSleepTime
    when "IFRAME"
      select_list(:id,/#{$app.slWidgetTypeId}/).select 'iFrame'
    when "IMAGE"
      select_list(:id,/#{$app.slWidgetTypeId}/).select 'GIF / JPG / PNG'
    end
    if widget.type.upcase == 'RSS'
      select_list(:id,/#{$app.slWidgetSizeId}/).select '300x250'
    else
      text_field(:id,/#{$app.tWidgetWidthId}/).set widget.width
      text_field(:id,/#{$app.tWidgetHeightId}/).set widget.height
    end
    link(:id,/#{$app.linkSaveBtnId}/,2301).click
    sleep 2  * GlobalAdjustedSleepTime
    if text.include?widget.name
      $logger.testcase("New Widget <#{widget.name}>  has been created",0)
    else
      $logger.testcase("Widget <#{widget.name}>  hasn't been created",1)
    end
  end
  def create_feed(feed)
    link(:id,/#{$app.linkManageContentFeedsId}/, 2304).click  unless $app.kind_of?ManageContentFeeds
    sleep 2  * GlobalAdjustedSleepTime
    ($logger.error "Unexpected page :<#{$app.name}>"; return) unless $app.kind_of?ManageContentFeeds
    $logger.info "Creating Feed  <#{feed.name}>"
    if link(:id,/#{$app.linkCreateNewFeedId}/).exists?
      link(:id,/#{$app.linkCreateNewFeedId}/,2303).click
    else
      link(:text,'create a new content feed',2303).click
    end
    text_field(:id,/#{$app.tFeedNameId}/).set feed.name
    text_field(:id,/#{$app.tFeedDescriptionId}/).set feed.description
    case feed.type.upcase
    when  "HTML"
      select_list(:id,/#{$app.slFeedTypeId}/).select 'HTML / JavaScript'
      sleep 1  * GlobalAdjustedSleepTime
      text_field(:id,/#{$app.tFeedCodeId}/).set feed.code
      feed.widgetAdSpaces.each { |was|                            ####create widget ad space
        link(:id,/#{$app.linkAddWidgetAdSpaceId}/,2303).click
        sleep 3  * GlobalAdjustedSleepTime
        text_field(:id,/#{$app.tWidgetAdSpaceNameId}/).set was.name
        select_list(:id,/#{$app.slWidgetImageSizeId}/).select /#{was.size}/
        sleep 1  * GlobalAdjustedSleepTime
        link(:id,/#{$app.linkSaveWidgetAdSpaceId}/,2303).click
        sleep 1  * GlobalAdjustedSleepTime
        if text.include?was.name
          $logger.testcase("New Widget Ad Space <#{was.name}> has been added to <#{feed.name}>",0)
        else
          $logger.testcase("The Widget Ad Space <#{was.name}> hasn't been created",1)
        end
      }
    when "FLASH"
      select_list(:id,/#{$app.slFeedTypeId}/).select 'Flash'
      sleep 1  * GlobalAdjustedSleepTime
      text_field(:id,/#{$app.tFeedImageSourceId}/).set feed.sourceURL if feed.sourceURL != ''
    when  "RSS"
      select_list(:id,/#{$app.slFeedTypeId}/).select 'RSS'
      sleep 1  * GlobalAdjustedSleepTime
      feed.widgetAdSpaces.each { |was|                            ####create widget ad space
        text_field(:id,/#{$app.tWidgetRSSAdSpaceNameId}/).set was.name
        $logger.testcase("New Widget Ad Space <#{was.name}> has been added to <#{feed.name}>",0)
      }
      text_field(:id,/#{$app.tFeedRSSSourceId}/).set feed.sourceURL if feed.sourceURL != ''
    when "IFRAME"
      select_list(:id,/#{$app.slFeedTypeId}/).select 'iFrame'
      sleep 1  * GlobalAdjustedSleepTime
      text_field(:id,/#{$app.tFeedRSSSourceId}/).set feed.sourceURL if feed.sourceURL != ''
    when "IMAGE"
      select_list(:id,/#{$app.slFeedTypeId}/).select 'GIF / JPG / PNG'
      sleep 1  * GlobalAdjustedSleepTime
      text_field(:id,/#{$app.tFeedImageSourceId}/).set feed.sourceURL if feed.sourceURL != ''
    end
    text_field(:id,/#{$app.tFeedWidthId}/).set feed.width if feed.width != ''
    text_field(:id,/#{$app.tFeedHeightId}/).set feed.height if feed.height != ''
    text_field(:id,/#{$app.tFeedDestinationURLId}/).set feed.destinationURL if feed.destinationURL != ''
    if feed.file != ''
      link(:id,/#{$app.linkUploadFromFileId}/,2303).click
      sleep 1  * GlobalAdjustedSleepTime
      file_field(:id,/#{$app.tFeedUploadFileId}/).set feed.file
      sleep 1  * GlobalAdjustedSleepTime
      link(:id,/#{$app.linkUploadBtnId}/).click
    end
    link(:id,/#{$app.linkSaveBtnId}/,2304).click
    sleep 1  * GlobalAdjustedSleepTime
    if text.include?feed.name
      $logger.testcase("New Feed <#{feed.name}> has been created",0)
    else
      $logger.testcase("The Feed <#{feed.name}> hasn't been created",1)
    end
  end
  ### ============================================================================
  def add_feed_to_widget(widget,feed)
    begin
      link(:id,/#{$app.linkWidgetDashboardId}/, 2301).click  #      unless $app.kind_of?WidgetDashboard
      sleep 2  * GlobalAdjustedSleepTime
      ind_widget = table(:id,/#{$app.tblWidgetListGridId}/).column_values(1).index(widget.name) + 1
      table(:id,/#{$app.tblWidgetListGridId}/)[ind_widget][2].link(:text,/#{$app.linkActionsText}/).click
      link(:id,/#{$app.linkAddFeedId}/).click
      sleep 5  * GlobalAdjustedSleepTime
      text_field(:id,/#{$app.tFeedsGridSearchId}/).set feed.name
      button(:id,/#{$app.btnFeedsGridSearchBtnId}/).click
      sleep 1  * GlobalAdjustedSleepTime
      checkbox(:id,/#{$app.cbFeedSearchSelectAllId}/).set
      link(:id,/#{$app.btnAddFeedDialogSaveId}/).click
      sleep 1  * GlobalAdjustedSleepTime
    rescue
      $logger.testcase("Exception on assign feed for <#{widget.name}>",1)
    end
    if table(:id,/#{$app.tblWidgetListGridId}/)[ind_widget][4].link(:text,/#{feed.name}/).exists?
      $logger.testcase("The Feed <#{feed.name}> has been assigned to the widget <#{widget.name}>",0)
    else
      $logger.testcase("Fail to find Feed <#{feed.name}> and assign it to widget <#{widget.name}>",1)
    end
  end
  ### ============================================================================
  def select_widget_site_list(widget)
    link(:id,/#{$app.linkWidDashID}/, 2301).click        unless $app.kind_of?WidgetDashboard
    sleep 2  * GlobalAdjustedSleepTime
    ($logger.error "Unexpected page :<#{$app.name}>"; return)          unless $app.kind_of?WidgetDashboard
    table(:id,/#{$app.tblWidgetListGridId}/)[table(:id,/#{$app.tblWidgetListGridId}/).column_values(1).index(widget.name) + 1][2].link(:text,/#{$app.linkActionsText}/).click
    link(:id,/#{$app.linkEditWidgetSiteListId}/,2305).click
    sleep 3  * GlobalAdjustedSleepTime
    case widget.location_type.upcase
    when  "FIXED NETWORK"
      radio(:id,/#{$app.rbPublishWidgetAllSitesId}/).set
      $logger.testcase("For widget <#{widget.name}> Option <Publish this widget on all sites> has been selected",0)
    when  "ROT"
      radio(:id,/#{$app.rbPublishWidgetTagsId}/).set
      $logger.testcase("For widget <#{widget.name}> Option <Publish this widget on all sites with these tags> has been selected",0)
    when  "ROS"
      widget.location.each { |loc|
        table(:id,/#{$app.tblWidgetSiteSelectId}/)[table(:id,/#{$app.tblWidgetSiteSelectId}/).column_values(2).index(loc) + 1][1].checkboxes[0].set
        $logger.testcase("New Site <#{loc}> has been added to <#{widget.name}> site list",0)
      }
      radio(:id,/#{$app.rbPublishWidgetOnSitesId}/).set
    end
    link(:id,/#{$app.linkSaveBtnId}/,2301).click
  end
  ### ============================================================================
  def publish_widget(widget)
    ($logger.error "Unexpected page :<#{$app.name}>"; return)          unless $app.kind_of?WidgetDashboard
    begin
      sleep 3  * GlobalAdjustedSleepTime
      table(:id,/#{$app.tblWidgetListGridId}/)[table(:id,/#{$app.tblWidgetListGridId}/).column_values(1).index(widget.name) + 1][3].link(:text,/#{$app.linkPublishText}/).click
    rescue
      $logger.testcase("Publish new widget <#{widget.name}>",1)
    end
    $logger.testcase("Widget <#{widget.name}> has been published",0)
  end
  ### ============================================================================
  def create_widget_space(site,widget)
    link(:text,/#{$app.linkSitesItext}/,2101).click
    sleep 2  * GlobalAdjustedSleepTime
    ($logger.error "Unexpected page :<#{$app.name}>"; return)          unless $app.kind_of?SitesAndPubNB
    table1 = get_table_from_div($app.tableSiteMainId)
    sleep 3  * GlobalAdjustedSleepTime
    my_row = find_row(table1, 'Site', site.name)
    if my_row
      my_row.cell(:class,/SiteActions/).links[0].click
      link(:id,/#{$app.linkCreateWidgetSpaceId}/,2306).click if link(:id,/#{$app.linkCreateWidgetSpaceId}/).visible?
      (refresh;return) unless $app.kind_of?CreateWidgetSpace
      sleep 3  * GlobalAdjustedSleepTime
    end
    labels.each do |l|
      if l.text.include?widget.name
        checkbox(:id,l.for).set
        temp_value = 1
        link(:id,/#{$app.linkSaveBtnId}/,2106).click
        link(:id,/#{$app.linkDoneBtnId}/,2101).click
        $logger.testcase("Widget Space for <#{widget.name}> has been created on site <#{site.name}>",0)
        break
      end
    end
    link(:id,/#{$app.linkCancelBtnId}/,2101).click  if $app.kind_of?CreateWidgetSpace
    sleep 3  * GlobalAdjustedSleepTime
  end
  ### ============================================================================
  def delete_widget_spaces(site)
    link(:text,/#{$app.linkSitesItext}/,2101).click
    sleep 2  * GlobalAdjustedSleepTime
    ($logger.error "Unexpected page :<#{$app.name}>"; return)          unless $app.kind_of?SitesAndPubNB
    table1 = get_table_from_div($app.tableSiteMainId)
    sleep 3  * GlobalAdjustedSleepTime
    my_row = find_row(table1, 'Site', site.name)
    if my_row
      my_row.cell(:class,/SiteActions/).links[0].click
      link(:id,/#{$app.linkEditWidgetSpaceId}/).click if link(:id,/#{$app.linkEditWidgetSpaceId}/).visible?
      sleep 3  * GlobalAdjustedSleepTime
    end
    (link(:text,'Delete widget space').click; sleep 2; link(:id,/deleteWidgetDialog_Delete/).click; sleep 2) until !link(:text,'Delete widget space').exist?
    $logger.info "All Widgets spaces have been deleted from site <#{site.name}>"
  end
  ### ============================================================================
  def delete_all_widgets
    link(:text,/#{$app.linkSitesItext}/, 220).click unless ($app.kind_of?SitesAndPubNB or $app.kind_of?WidgetDashboard)
    sleep 2  * GlobalAdjustedSleepTime
    link(:id,/#{$app.linkWidDashID}/, 2301).click        unless $app.kind_of?WidgetDashboard
    ($logger.error "Unexpected page :<#{$app.name}>"; return)     unless $app.kind_of?WidgetDashboard
    sleep 1  * GlobalAdjustedSleepTime
    (link(:text,'Actions').click; sleep 1; link(:id,/WidgetActionButton_DeleteWidget/).click; sleep 1; link(:id,/DeleteWidgetDialog_Delete/).click; sleep 1) until !link(:text,'Actions').exist?
    $logger.info "All Widgets  have been deleted from network"
  end
  ### ============================================================================
  def delete_all_feeds
    link(:id,/#{$app.linkManageContentFeedsId}/, 2304).click  unless $app.kind_of?ManageContentFeeds
    sleep 2  * GlobalAdjustedSleepTime
    ($logger.error "Unexpected page :<#{$app.name}>"; return) unless $app.kind_of?ManageContentFeeds
    sleep 1  * GlobalAdjustedSleepTime
    (link(:text,'delete').click; sleep 1; link(:id,/DeleteFeedDialog_Delete/).click; sleep 1) until !link(:text,'delete').exist?
    $logger.info "All Feeds have been deleted from network"
  end
  # ====================================  ## Ramesh Yatam until
  def set_line_item_location(line)
    return($logger.error "Unexpected page :<#{$app.name}>") unless $app.kind_of?NetworkCS
    link(:href,/#{$app.linkSalesHref}/, 3101).click if $app.kind_of?NetworkCS
    link(:id, /#{$app.linkCampaignsId}/, 3101).click
    link(:text, /#{line.campaign.name}/,3102).click
    div(:id,/#{$app.divClientTabViewId}/).link(:text,/#{$app.linkLineItemsBtnItext}/).click
    $app = LineItemPage.new
    select_location(line)
  end
  ## Ramesh Yatam until ## Ramesh Yatam Added
  def check_all_columns_editpre(opt)
    sleep 5  * GlobalAdjustedSleepTime
    option = select_list(:id,/#{$app.defaultLang}/).getAllContents
    select_list(:id,/#{$app.defaultLang}/).select option[opt]
    checkbox(:id,/#{$app.mediaBuyNot}/).set
    checkbox(:id,/#{$app.accountSum}/).set
    sleep 5  * GlobalAdjustedSleepTime
    radio(:id,/#{$app.weekly}/).set
    checkbox(:id,/#{$app.autoRejectMB}/).set
    link(:id,/#{$app.linkSaveBtnId}/).click
    sleep 10  * GlobalAdjustedSleepTime
    return option
  end
  ## ==================================== ## Ramesh Yatam   ## Ramesh Yatam until
  def ChangePassword(currPwd,newPwd)
    text_field(:id,/#{$app.eCurrentPwd}/).set currPwd
    text_field(:id,/#{$app.eNewPwd}/).set newPwd
    text_field(:id,/#{$app.eConfirmPwd}/).set newPwd
    sleep 1  * GlobalAdjustedSleepTime
    link(:id,/#{$app.linkSaveBtnId}/).click
    sleep 5  * GlobalAdjustedSleepTime
  end
  ## ====================================
  def impersonate_pub_by_name(pub)
    text_field(:id, /#{$app.tSearchId}/).set pub.name
    select_list(:id, /#{$app.slFilterSearchId}/).select "Users"
    button(:id, /#{$app.btnSearchId}/).click
    sleep 7  * GlobalAdjustedSleepTime
    my_table_body = div(:id, /#{$app.tblSeachResultId}/).table(:index, 1)
    myRow = findExactRow(my_table_body, 'Name', pub.name)
    myRow.link(:text, "Publisher").click
  end
  ## ====================================
  def findExactRow(table1, colName,text)
    col_num = table1.row_values(1).index(colName)+1
    length_of_text_limit = (text.length<25)?(text.length):25
    text_to_find = text[0,length_of_text_limit]
    myRow = table1.rows.find {|row|  (row.column_count > 1) && (row[col_num].to_s.eql?text_to_find)}
    return myRow if myRow
    $logger.error("find_row method: Row with text #{text_to_find} in column <#{colName}> is not found") unless myRow
  end
  ## ====================================
  def stringCmp(str1, str2)
    err_code=0
    if str1.to_s.eql?str2
      $logger.testcase(str1+" is updated successfully",0)
    else
      $logger.testcase(str1+ " is not updated successfully",1)
      err_code = 1
    end
    return err_code
  end
  ## ====================================
  def testcase_status(errCode,testCaseId)
    if errCode > 0
      $logger.info "----------------------------------------------------------------------"
      $logger.info "---------------------Testcase Id <#{testCaseId}> FAIL-------------------------"
      $logger.info "----------------------------------------------------------------------"
    else
      $logger.info "----------------------------------------------------------------------"
      $logger.info "---------------------Testcase Id <#{testCaseId}> PASS ------------------------"
      $logger.info "----------------------------------------------------------------------"
    end
  end
  ## ====================================
  def edit_contactDetails
    text_field(:id,/#{$app.eFirstNameId}/).set 'test1'
    text_field(:id,/#{$app.eLastNameId}/).set 'lastNameTest1'
    text_field(:id,/#{$app.eEmailAddId}/).set 'test@adify.com'
    text_field(:id,/#{$app.ePhoneNumberId}/).set '1234735645868'
    text_field(:id,/#{$app.eCompanyId}/).set 'Adify'
    text_field(:id,/#{$app.eAddress1Id}/).set 'sanburno'
    text_field(:id,/#{$app.eAddress2Id}/).set 'Hyd1'
    text_field(:id,/#{$app.eCityId}/).set 'sanburno'
    option = select_list(:id,/#{$app.eStateDropDownListId}/).getAllContents
    select_list(:id,/#{$app.eStateDropDownListId}/).select option[6]
    text_field(:id,/#{$app.ePostalCodeTextBoxid}/).set '23438448'
    sleep 20  * GlobalAdjustedSleepTime
    link(:id,/#{$app.linkSave}/).click
  end
  ## ====================================
  def ValidateContactDetails
    if fn == "test1" && ln == "lastNameTest1" && email == "test@adify.com" && phoneNm == "1234735645868" && cmpy == "Adify" && add1 == "sanburno"
      add2 == "Hyd1"  && city == "sanburno" && state == "Colorado" && zip == "23438448"
      $logger.testcase("first,last name,email,phonenum,company,addess,cit,state,zip are updated",0)
    else
      puts "Test failed"
      $logger.testcase("first,last name,email,phonenum,company,addess,cit,state,zip are did't update",1)
    end
  end
  ## ====================================
  def edit_preferencesinfo
    option = select_list(:id,/#{$app.defaultLang}/).getAllContents
    select_list(:id,/#{$app.defaultLang}/).select option[0]
    sleep 5  * GlobalAdjustedSleepTime
    link(:id,/#{$app.linkSaveBtnId}/).click
  end
  ## ====================================
  def edit_Billingmethod
    radio(:id,/#{$app.sMonthlyCreditCardInvoice}/).set
    option = select_list(:id,/#{$app.sCreditCardtype}/).getAllContents
    select_list(:id,/#{$app.sCreditCardtype}/).select option[1]
    text_field(:id,/#{$app.eCreditCardNum}/).set "5534345697674012"
    option = select_list(:id,/#{$app.sExpMonth}/).getAllContents
    select_list(:id,/#{$app.sExpMonth}/).select option[2]
    option = select_list(:id,/#{$app.sExpYear}/).getAllContents
    select_list(:id,/#{$app.sExpYear}/).select option[3]
    checkbox(:id,/#{$app.uCreditCardAdd}/).set
    link(:id,/#{$app.linksaveBtnId}/).click
  end
  ## ====================================
  def edit_payoutmethod
    option = select_list(:id,/#{$app.sPayoutMethod}/).getAllContents
    select_list(:id,/#{$app.sPayoutMethod}/).select option[1]
    text_field(:id,/#{$app.ePaypalac}/).set 'kbolla@adify.com'
    link(:id,/#{$app.lPaySaveBtn}/).click
  end
  ## ====================================
  def edit_w9TaxInfo
    option = select_list(:id,/#{$app.sCompanyType}/).getAllContents
    select_list(:id,/#{$app.sCompanyType}/).select option[3]
    text_field(:id,/#{$app.eTaxId}/).set '12-3456789'
    sleep 5  * GlobalAdjustedSleepTime
    link(:id,/#{$app.lW9SaveBtn}/).click
  end
  ## ====================================   # Ramesh Yatam ended ## Shaik Salam Added
  def view_manage_mediabuy_pricing(site1)
    ## table1 = div(:id,/#{$app.tableSiteMainId}/).table(:index,1)
    table1 = get_table_from_div($app.tableSiteMainId)
    myRow = find_row(table1, 'Site', site1.name)
    myRow.link(:text =>'Actions', :index => 1).click
    link(:id,/#{$app.newViewAdSpaces}/).click ##
    link(:id,/#{$app.editAdZoneButton}/).click
    checkbox(:id, /#{$app.AdSpaceDataTablejsCheckState}/).set
    link(:id,/#{$app.editAdZonePricing}/).click
    sleep   45 * GlobalAdjustedSleepTime
    text_field(:id,/#{$app.adSpacePriceMinCPMPrice}/).set("2.0")
    text_field(:id,/#{$app.adSpacePriceMinCPMNonDomestic}/).set("3.0")
    text_field(:id,/#{$app.adSpacePriceMinCPCPrice}/).set("4.0")
    text_field(:id,/#{$app.adSpacePriceMinCPCNonDomestic}/).set("5.0")
    link(:id,/#{$app.adSpacePriceSave}/).click
    sleep 5  * GlobalAdjustedSleepTime
  end
  ## ====================================
  def OpenAdSpaceInNewWindow(site1)
    ## table1 = div(:id,/#{$app.tableSiteMainId}/).table(:index,1)
    ## table1 = get_main_site_table
    table1 = get_table_from_div($app.tableSiteMainId)
    myRow = find_row(table1, 'Site', site1.name)
    myRow.link(:text =>'Actions', :index => 1).click
    link(:id,/#{$app.newViewAdSpaces}/).click
  end
  ### =========Kalpana added==============================
  def impersonate_adv_by_name(advName)
    text_field(:id, /#{$app.tSearchId}/).set advName
    select_list(:id, /#{$app.slFilterSearchId}/).select "Users"
    button(:id, /#{$app.btnSearchId}/).click
    sleep 7
    my_table_body = div(:id, /#{$app.tblSeachResultId}/).table(:index, 1)
    myRow = find_row(my_table_body, 'Name', advName)
    sleep 5  * GlobalAdjustedSleepTime
    myRow.link(:text, "Advertiser").click
  end
  ## ==================================== ### Ramesh Amaravadi
  def pub_add_anothermodule(modulename)
    $app = PubDashboard.new
    begin
      modules = divs.collect { |d| d.id if d.id =~ /#{$app.module_id}/ }.compact
      btnid = modules.first.split($app.module_id).last + $app.btnaddanothermodule
      button(:id,btnid).click
      radio(:value, modulename).set
      link(:id, /#{$app.btnModuleDialog_id}/).click
    rescue => ex
      $logger.testcase("Error in adding another module, Error Info: #{ex.message}",1)
    end
    return btnid
    sleep 2  * GlobalAdjustedSleepTime
  end
  ### =========
  def pub_create_report(email)
    $app = PubDashboard.new
    begin
      link(:href, /#{$app.lnkreport}/).click
      $app = PubReportTab.new
      link(:id, /#{$app.btnViewReport1}/).click
      link(:id, /#{$app.emailButton}/).click
      sleep 3  * GlobalAdjustedSleepTime
      text_field(:id, /#{$app.recipientsValue}/).set(email)
      text_field(:id, /#{$app.subjectValue}/).set("last 30 days report")
      text_field(:id, /#{$app.messageValue}/).set("Publisher last 30 days report")
      link(:id, /#{$app.btnEmailReportDialog}/).click
    rescue => ex
      $logger.testcase("Error: Error in creating publisher report, Error Info: #{ex.message}",1)
    end
  end
  ### =========
  def pub_validate_module_added(moduletext,btnid)
    sleep 3  * GlobalAdjustedSleepTime
    spanModuleTitle_id = btnid.split($app.btnaddanothermodule).last + $app.ModuleTitle
    if span(:id,spanModuleTitle_id).text == moduletext
      $logger.testcase("<#{moduletext}> module is added to publisher dash board",0)
      errCode = 0
    else
      $logger.testcase("<#{moduletext}> module is not added to publisher dash board",1)
      errCode = 1
    end
    return errCode
  end
  ### ========= # Gayatri
  def forgot_password_link(userName,emailId)
    $app = HomePage.new
    sleep 3  * GlobalAdjustedSleepTime
    link(:id, /#{$app.idForgotPassword}/, 9100).click
    sleep 5  * GlobalAdjustedSleepTime
    $app = ForgotPasswordPage.new
    text_field(:id, /#{$app.UserId_textId}/).set userName
    $logger.info "User name is entered into User ID text field"
    sleep 3  * GlobalAdjustedSleepTime
    link(:id, /#{$app.linkNextFPId}/).click
    sleep 3  * GlobalAdjustedSleepTime
    text_field(:id, /#{$app.Email_textId}/).set emailId
    $logger.info "Email Address is entered into Email Address text field"
    sleep 3  * GlobalAdjustedSleepTime
    link(:id, /#{$app.linkNextFPId}/).click
    if contains_text("Thank You")
      link(:id, /#{$app.linkThankId}/).click
      $logger.info "Reset of password for <#{userName}> is done and mail is sent to <#{emailId}> "
    else
      $logger.info "Fail"
    end
  end
  ### ========= # gayatri
  def fill_out_NetworkUser(uName,fName,lName,uTitle,emailAddress,phoneNumber)
    $app = CreateNkUsersNB.new
    text_field(:id, /#{$app.tUserNameId}/).set uName
    text_field(:id, /#{$app.tFirstNameId}/).set fName
    text_field(:id, /#{$app.tLastNameId}/).set lName
    text_field(:id, /#{$app.tUserTitleId}/).set uTitle
    text_field(:id, /#{$app.tEmailAddressId}/).set emailAddress
    text_field(:id, /#{$app.tPhoneNumberId}/).set phoneNumber
  end
  ### ========= # Dipanshu M
  def fill_out_AdSpace(adSpace)
    table_adspaces = div(:id,/BodyContent_AdSpacesTable/).tables[0] ## div(:id,/#{$app.divAdTableId}/)
    row_to_fill = table_adspaces.rows[table_adspaces.row_count]
    dialog_text_field_set(row_to_fill.cell(:class,/#{$app.tdNameClass}/),adSpace.name,"adSpace name")
    dialog_text_field_set(row_to_fill.cell(:class,/#{$app.tdDescriptionClass}/),adSpace.description, "adSpace description")
    dialog_select_list_set(row_to_fill.cell(:class,/#{$app.tdSizeIdClass}/),adSpace.size, "dSpace size")
    sleep 3  * GlobalAdjustedSleepTime
    dialog_text_field_set(row_to_fill.cell(:class,/#{$app.tdSiteDomainClass}/),adSpace.domainName, "adSpace domainName")
    dialog_select_list_set(row_to_fill.cell(:class,/#{$app.tdPagePositionClass}/),adSpace.pagePosition, "adSpace pagePosition")
    dialog_select_list_set(row_to_fill.cell(:class,/#{$app.tdClickLocationClass}/),adSpace.openInNewWindow, "adSpace openInNewWindow")
    dialog_text_field_set(row_to_fill.cell(:class,/#{$app.tdThirdPartyURLClass}/),adSpace.thirdPartyUrl, "adSpace thirdPartyUrl")
    link(:id,/#{$app.linkSaveBtnId}/,2104).click
    adSpace.tag = text_field(:id,/#{$app.textAdTagId}/).value.to_s
    ## adSpace.o_Id = adSpace.tag.scan(/sr_adspace_id = [\d]*/).to_s.split('=')[1].to_i
    adSpace.o_Id = adSpace.tag.match(/sr_adspace_id = (\d*)/)[1].to_i
    link(:id,/#{$app.linkDoneBtnId}/,2101).click
    $logger.info("Ad Space <#{adSpace.name}> has been added to the site")
  end
  ## ====================================
  def sample
    sleep 5  * GlobalAdjustedSleepTime
    @table_adspaces = div(:id,/BodyContent_clientTabView_LineItemTable/).tables[0]
    @row_to_fill = find_row(@table_adspaces, 'Line item','Test campaign - 3')
    dialog_text_field_set(@row_to_fill[@table_adspaces.row_values(1).index('Budget')+1],"0")
  end
  ## ==================================== created by Devisree
  def SiteActionAdspace(adSpace)
    table_adspaces = div(:id,/site_AdSpaceDataTable/).tables[0]
    row_to_fill = table_adspaces.rows[table_adspaces.row_count]
    dialog_text_field_set(row_to_fill.cell(:class,/#{$app.tdNameClass}/),adSpace.name,"adSpace name")
    sleep 3  * GlobalAdjustedSleepTime
    dialog_text_area_set(row_to_fill.cell(:class,/#{$app.tdDescriptionClass}/),adSpace.description, "adSpace description")
  end
  ## ====================================
  def impersonate_net_by_name_method02(netBuilder)
    text_field(:id, /#{$app.tSearchId}/).set netBuilder.name
    select_list(:id, /#{$app.slFilterSearchId}/).select "Users"
    button(:id, /#{$app.btnSearchId}/).click
    sleep 2  * GlobalAdjustedSleepTime
    myTableBody = div(:id, /#{$app.tblSeachResultId}/).table(:index, 1)
    myRow = findExactRow(myTableBody, 'Name', netBuilder.name)
    myRow.link(:text, "Network builder").click
  end
  ## ====================================
  def set_alerts(netBuilder)
    ($logger.error("Unexpected page <#{$app.name}>") ;return) unless $app.kind_of?EditAlerts
    checkbox(:id, /#{$app.cbOSIRisesId}/).set if (netBuilder.alerts[0].osi_set.casecmp "true") == 0
    text_field(:id, /#{$app.tOSIRiseValueId}/).set netBuilder.alerts[0].osi_rises_above
    text_field(:id, /#{$app.tOSIFallValueId}/).set netBuilder.alerts[0].osi_falls_below
    checkbox(:id, /#{$app.cbCTRRisesId}/).set if (netBuilder.alerts[0].ctr_set.casecmp "true") == 0
    text_field(:id, /#{$app.tCTRAboveValueId}/).set netBuilder.alerts[0].ctr_rises_above
    text_field(:id, /#{$app.tCTRBelowValueId}/).set netBuilder.alerts[0].ctr_falls_below
    checkbox(:id, /#{$app.cbCTRRises7daysId}/).set if (netBuilder.alerts[0].ctr7_set.casecmp "true") == 0
    text_field(:id, /#{$app.tCTR7daysPercentId}/).set netBuilder.alerts[0].ctr7_days
    checkbox(:id, /#{$app.cbSiteZeroImpId}/).set if (netBuilder.alerts[0].site_imp_drop_0.casecmp "true") == 0
    checkbox(:id, /#{$app.cbCampEndsTodayId}/).set if (netBuilder.alerts[0].camp_ends_today.casecmp "true") == 0
    checkbox(:id, /#{$app.cbTotalImpRisesId}/).set if (netBuilder.alerts[0].imp_rises_falls_set.casecmp "true") == 0
    text_field(:id, /#{$app.tTotalImpValueId}/).set netBuilder.alerts[0].imp_rises_falls
    checkbox(:id, /#{$app.cbECpmRises7DaysId}/).set if (netBuilder.alerts[0].ecpm_rises_falls_set.casecmp "true") == 0
    text_field(:id, /#{$app.tECpmValueId}/).set netBuilder.alerts[0].ecpm_rises_falls
    checkbox(:id, /#{$app.cbBudgetSpentId}/).set if (netBuilder.alerts[0].budget_rises_falls_set.casecmp "true") == 0
    text_field(:id, /#{$app.tBudgetSpentValueId}/).set netBuilder.alerts[0].budget_rises_falls
    radio(:id,/#{$app.rbMyCampAlertsId}/).set if (netBuilder.alerts[0].alert_sales_team.casecmp "true") == 0
    radio(:id,/#{$app.rbAllCampAlertsId}/).set if (netBuilder.alerts[0].alert_all_camp.casecmp "true") == 0
    checkbox(:id, /#{$app.cbSitesRemovedId}/).set if (netBuilder.alerts[0].sites_removed.casecmp "true") == 0
    checkbox(:id, /#{$app.cbNewSitesId}/).set if (netBuilder.alerts[0].new_sites.casecmp "true") == 0
    link(:id,/#{$app.linkSaveButtonId}/,6101).click
  end
  ## ====================================
  def clear_alerts(netBuilder)
    ($logger.error("Unexpected page <#{$app.name}>") ;return) unless $app.kind_of?EditAlerts
    checkbox(:id, /#{$app.cbOSIRisesId}/).clear
    checkbox(:id, /#{$app.cbCTRRisesId}/).clear
    checkbox(:id, /#{$app.cbCTRRises7daysId}/).clear
    checkbox(:id, /#{$app.cbSiteZeroImpId}/).clear
    checkbox(:id, /#{$app.cbCampEndsTodayId}/).clear
    checkbox(:id, /#{$app.cbTotalImpRisesId}/).clear
    checkbox(:id, /#{$app.cbECpmRises7DaysId}/).clear
    checkbox(:id, /#{$app.cbBudgetSpentId}/).clear
    radio(:id,/#{$app.rbMyCampAlertsId}/).clear
    radio(:id,/#{$app.rbAllCampAlertsId}/).clear
    checkbox(:id, /#{$app.cbSitesRemovedId}/).clear
    checkbox(:id, /#{$app.cbNewSitesId}/).clear
    link(:id,/#{$app.linkSaveButtonId}/,6101).click
  end
  ## ====================================
  def check_alerts(netBuilder)
    def verify_checkbox(checkBox, checkBoxStatus)
      if checkBoxStatus == 0
        if checkBox.checked?
          $logger.testcase("<#{checkBox.id}> checkbox has status checked as expected",0)
        else
          $logger.testcase("<#{checkBox.id}> checkbox has wrong status unchecked",1)
        end
      else
        if !checkBox.checked?
          $logger.testcase("<#{checkBox.id}> checkbox has status not checked as expected",0)
        else
          $logger.testcase("<#{checkBox.id}> checkbox has wrong status checked",1)
        end
      end
    end
    ($logger.error("Unexpected page <#{$app.name}>") ;return) unless $app.kind_of?EditAlerts
    sleep 3  * GlobalAdjustedSleepTime
    verify_checkbox(checkbox(:id, /#{$app.cbOSIRisesId}/), (netBuilder.alerts[0].osi_set.casecmp "true"))
    verify_checkbox(checkbox(:id, /#{$app.cbCTRRisesId}/), (netBuilder.alerts[0].ctr_set.casecmp "true"))
    verify_checkbox(checkbox(:id, /#{$app.cbCTRRises7daysId}/), (netBuilder.alerts[0].ctr7_set.casecmp "true"))
    verify_checkbox(checkbox(:id, /#{$app.cbSiteZeroImpId}/), (netBuilder.alerts[0].site_imp_drop_0.casecmp "true"))
    verify_checkbox(checkbox(:id, /#{$app.cbCampEndsTodayId}/), (netBuilder.alerts[0].camp_ends_today.casecmp "true"))
    verify_checkbox(checkbox(:id, /#{$app.cbTotalImpRisesId}/), (netBuilder.alerts[0].imp_rises_falls_set.casecmp "true"))
    verify_checkbox(checkbox(:id, /#{$app.cbECpmRises7DaysId}/), (netBuilder.alerts[0].ecpm_rises_falls_set.casecmp "true"))
    verify_checkbox(checkbox(:id, /#{$app.cbBudgetSpentId}/), (netBuilder.alerts[0].budget_rises_falls_set.casecmp "true"))
    verify_checkbox(checkbox(:id, /#{$app.cbSitesRemovedId}/), (netBuilder.alerts[0].sites_removed.casecmp "true"))
    verify_checkbox(checkbox(:id, /#{$app.cbNewSitesId}/), (netBuilder.alerts[0].new_sites.casecmp "true"))
    link(:id,/#{$app.linkSaveButtonId}/,6101).click
  end
  #dipanshu
  def verifySpanValue(objectVal, compareVal)
    errTest = 0
    if compareVal == objectVal
      $logger.info compareVal + " can be seen."
    else
      $logger.info compareVal + " cannot be seen."
      errTest = 1
      $logger.testcase(compareVal + " cannot be seen.", errTest)
    end
    return errTest;
  end
  ### =========
  def CheckBoxPresent(object)
    errTest = 0
    if checkbox(:id,/#{object}/).exists?
      $logger.info "checkbox " + object + " exists."
    else
      $logger.info "checkbox " + object + " does not exists."
      errTest = 1
      $logger.testcase("checkbox " + object + " does not exists.", errTest)
    end
    return errTest;
  end
  ### =========
  def CheckBoxUnchecked(object)
    val = checkbox(:id,/#{object}/).checked?
    puts val
    str2 = "false"
      
    errTest = 0
    if val.to_s.eql?str2
      $logger.info "checkbox " + object + " is not checked."
    else
      $logger.info "checkbox " + object + " is checked."
      errTest = 1
      $logger.testcase("checkbox " + object + " is checked." , errTest)
    end
    return errTest
  end
  ### =========
  def RadioButtonExists(object)
    errTest = 0
    if radio(:id,/#{object}/).exists?
      $logger.info "Radio button " + object + " exists."
    else
      $logger.info "Radio button " + object + " does not exists."
      errTest = 1
      $logger.testcase("Radio button " + object + " does not exists." , errTest)
    end
    return errTest
  end
  ### =========
  def LinkExists(object)
    errTest = 0
    if link(:id,/#{object}/).exists?
      $logger.info "link " + object + " exists."
    else
      $logger.info "link " + object + " does not exists."
      errTest = 1
      $logger.testcase("link " + object + " does not exists."  , errTest)
    end
    return errTest
  end
  ### =========
  def link_exists(property,object) #nextPageID
    errTest = 0

    if link(:text,/#{object}/).exists?
      #$logger.testcase("link " + object + "exists."  , errTest)
      $logger.info "link " + object + "exists."
    else
      errTest = 1
      #$logger.testcase("link " + object + " does not exists."  , errTest)
      $logger.info "link " + object + "Does not exists."
    end
    #unless nextPageID == 0
    #$app.navigate nextPageID
    return errTest
  end
  ### =========
  def verifyTextValue(objectVal, compareVal)
    errTest = 0
    if compareVal.to_s.eql?objectVal
      $logger.info objectVal + " value is equal to " + compareVal
    else
      $logger.info objectVal + " value is not equal to " + compareVal
      errTest = 1
      $logger.testcase(objectVal + " value is not equal to " + compareVal , errTest)
    end
    return errTest
  end
  ### =========
  def VerifyTextValueAlerts(alert)
    errTest = verifyTextValue(text_field(:id,/#{$app.tOSIRiseValueId}/).value, alert.osi_rises_above)
    errTest = verifyTextValue(text_field(:id,/#{$app.tOSIFallValueId}/).value, alert.osi_falls_below)
    errTest = verifyTextValue(text_field(:id,/#{$app.tCTRAboveValueId}/).value, alert.ctr_rises_above)
    errTest = verifyTextValue(text_field(:id,/#{$app.tCTRBelowValueId}/).value, alert.ctr_falls_below)
    errTest = verifyTextValue(text_field(:id,/#{$app.tCTR7daysPercentId}/).value, alert.ctr7_days)
    errTest = verifyTextValue(text_field(:id,/#{$app.tTotalImpValueId}/).value, alert.imp_rises_falls)
    errTest = verifyTextValue(text_field(:id,/#{$app.tECpmValueId}/).value, alert.ecpm_rises_falls)
    errTest = verifyTextValue(text_field(:id,/#{$app.tBudgetSpentValueId}/).value, alert.budget_rises_falls)
  end
  ### =========
  def setTextValueAlerts(alert)
    text_field(:id,/#{$app.tOSIRiseValueId}/).set alert.osi_rises_above
    text_field(:id,/#{$app.tOSIFallValueId}/).set alert.osi_falls_below
    text_field(:id,/#{$app.tCTRAboveValueId}/).set alert.ctr_rises_above
    text_field(:id,/#{$app.tCTRBelowValueId}/).set alert.ctr_falls_below
    text_field(:id,/#{$app.tCTR7daysPercentId}/).set alert.ctr7_days
    text_field(:id,/#{$app.tTotalImpValueId}/).set alert.imp_rises_falls
    text_field(:id,/#{$app.tECpmValueId}/).set alert.ecpm_rises_falls
    text_field(:id,/#{$app.tBudgetSpentValueId}/).set alert.budget_rises_falls
  end
  ### =========
  def verifyEditAlerts(errTest,netBuilder1, layout)
    alertDefault = Alert.new(netBuilder1,$qa_server.get_hash_from_db('Alerts',"alert_default"), $timeStamp)
    if layout == 'page'
      $app = EditAlertsAccMng.new
      id = getSpanValue $app.spanPageTitle
      puts id
      if id == 'Edit Alerts'
        $logger.info "Page Title 'Edit Alerts' can be seen."
      else
        $logger.info "FAIL. " + "Page Title 'Edit Alerts' cannot be seen."
        errTest = 1
      end   
      id = getSpanValue $app.spanInstructions
      puts id
      if id == 'Check the alerts that you would like to recieve. Alerts are generated nightly and will be emailed to you at:'
        $logger.info "Instructions label can be seen."
      else
        $logger.info "FAIL. " + "Instructions label cannot be seen."
        errTest = 1
      end 
      errTest = LinkExists($app.btnEditNetworks)
    elsif layout == 'dialog'
      $app = EditAlertsUsers.new
      if div(:id,/#{$app.dialogTitle}/).exists?
        $logger.testcase("Edit Alerts dialog displayed", 0)
      else
        $logger.testcase("Edit Alerts Dialog is not displayed", 1)
        errTest = 1
      end
      id = div(:id,/#{$app.dialogBody}/).text
      idSplit = id.split(':')
      puts idSplit[0]
      idLabel = idSplit[0] + ':'         
      if idLabel == 'Check the alerts that you would like to recieve. Alerts are generated nightly and will be emailed to you at:'
        $logger.info "Instructions label can be seen."
      else
        $logger.info "FAIL. " + "Instructions label cannot be seen."
        errTest = 1
      end
    end
    puts netBuilder1.email
    puts netBuilder1.contactEmail  
    if link(:href,/#{netBuilder1.email}/).exists?
      $logger.info "href; Email found." + netBuilder1.email
    else
      $logger.info "FAIL. " + "href; Email not found. " + netBuilder1.email
      errTest = 1
    end
    errTest = CheckBoxPresent($app.cbOSIRisesId);
    errTest = CheckBoxUnchecked($app.cbOSIRisesId);  
    errTest = CheckBoxPresent($app.cbCTRRisesId);
    errTest = CheckBoxUnchecked($app.cbCTRRisesId);   
    errTest = CheckBoxPresent($app.cbCTRRises7daysId);
    errTest = CheckBoxUnchecked($app.cbCTRRises7daysId);
    errTest = CheckBoxPresent($app.cbSiteZeroImpId);
    errTest = CheckBoxUnchecked($app.cbSiteZeroImpId);
    errTest = CheckBoxPresent($app.cbCampEndsTodayId);
    errTest = CheckBoxUnchecked($app.cbCampEndsTodayId);
    errTest = CheckBoxPresent($app.cbTotalImpRisesId);
    errTest = CheckBoxUnchecked($app.cbTotalImpRisesId);
    errTest = CheckBoxPresent($app.cbECpmRises7DaysId);
    errTest = CheckBoxUnchecked($app.cbECpmRises7DaysId);
    errTest = CheckBoxPresent($app.cbBudgetSpentId);
    errTest = CheckBoxUnchecked($app.cbBudgetSpentId);
    errTest = CheckBoxPresent($app.cbSitesRemovedId);
    errTest = CheckBoxUnchecked($app.cbSitesRemovedId);
    errTest = CheckBoxPresent($app.cbNewSitesId);
    errTest = CheckBoxUnchecked($app.cbNewSitesId);
    RadioButtonExists($app.rbMyCampAlertsId)
    RadioButtonExists($app.rbAllCampAlertsId)
    VerifyTextValueAlerts(alertDefault)   
    errTest = LinkExists($app.linkCancelButtonId)
    errTest = LinkExists($app.linkSaveButtonId)
    return errTest
  end

  def verifyEditAlertsEditCancel(errTest,netBuilder1, userType)
    alertDefault = Alert.new(netBuilder1,$qa_server.get_hash_from_db('Alerts',"alert_default"), $timeStamp)
    alertChange  = Alert.new(netBuilder1,$qa_server.get_hash_from_db('Alerts',"alert_change"), $timeStamp)
    setTextValueAlerts(alertChange)
    if userType == 'CSUser'
      $app = EditAlertsAccMng.new
      link(:id,/#{$app.linkCancelButtonId}/).click
      sleep 10  * GlobalAdjustedSleepTime
      $app = EditUser.new
      link(:id,/#{$app.btnEditAlerts}/).click
      sleep 10  * GlobalAdjustedSleepTime
      $app = EditAlertsAccMng.new
    elsif userType == 'NetworkManager' || userType == 'NetworkUser'
      $app = EditAlertsUsers.new
      link(:id,/#{$app.linkCancelButtonId}/).click
      sleep 10  * GlobalAdjustedSleepTime
      $app = UsersNB.new
      my_table_body = div(:id, /#{$app.tblNetworkUsers}/).table(:index, 1)
      myRow = findExactRow(my_table_body, 'User', netBuilder1.name)  #'ATNB_1_20110122_153026') #
      myRow.link(:text =>'Actions', :index => 1).click
      link(:id,/#{$app.actionsEditAlerts}/).click
      sleep 10  * GlobalAdjustedSleepTime
      $app = EditAlertsUsers.new
    elsif userType == 'NetworkBuilder'
      $app = EditAlertsUsers.new
      link(:id,/#{$app.linkCancelButtonId}/).click
      sleep 10  * GlobalAdjustedSleepTime
      $app = PreferencesTab.new
      link(:id,/#{$app.linkEditAlertId}/).click
      sleep 10  * GlobalAdjustedSleepTime
      $app = EditAlertsUsers.new
    end
    VerifyTextValueAlerts(alertDefault) 
    return errTest
  end
  ## ====================================
  def selectNetworksEditAlerts(errTest)
    $app = EditUser.new
    link(:id,/#{$app.btnEditAlerts}/).click
    sleep 10  * GlobalAdjustedSleepTime
    $app = EditAlertsAccMng.new
    link(:id,/#{$app.btnEditNetworks}/).click
    sleep 10  * GlobalAdjustedSleepTime
    $app = SelectNetworksDialog.new
    for i in 0..9
      str = $app.cbSelectedNetwork + i.to_s
      puts str
      if checkbox(:id,/#{str}/).exists?
        val = checkbox(:id,/#{str}/).set
        puts val
      end
    end
    link(:id,/#{$app.btnSelect}/).click
    sleep 10  * GlobalAdjustedSleepTime 
    $app = EditAlertsAccMng.new
    link(:id,/#{$app.btnEditNetworks}/).click
    $app = SelectNetworksDialog.new
    button(:id,/#{$app.btnShowOnlySelected}/).click
    sleep 10  * GlobalAdjustedSleepTime
    $app = SelectNetworksDialog.new
    for i in 0..9
      str = $app.cbSelectedNetwork + i.to_s
      puts str
      if checkbox(:id,/#{str}/).exists?
        val = checkbox(:id,/#{str}/).checked?
        puts val 
        if val == "false"
          $logger.info "checkbox " + str + " is not checked."
          errTest = 1
        else
          $logger.info "checkbox " + str + " is checked."
        end
      end
    end
    link(:id,/#{$app.btnCancel}/).click
    sleep 10  * GlobalAdjustedSleepTime
    $app = EditAlertsAccMng.new
    link(:id,/#{$app.btnEditNetworks}/).click
    sleep 10  * GlobalAdjustedSleepTime
    $app = SelectNetworksDialog.new
    checkbox(:id,/#{$app.cbSelectAllOnPage}/).set
    link(:id,/#{$app.btnSelect}/).click
    sleep 10  * GlobalAdjustedSleepTime
    $app = EditAlertsAccMng.new
    link(:id,/#{$app.btnEditNetworks}/).click
    $app = SelectNetworksDialog.new
    for i in 0..14
      str = $app.cbSelectedNetwork + i.to_s
      puts str    
      if checkbox(:id,/#{str}/).exists?
        val = checkbox(:id,/#{str}/).checked?
        puts val  
        if val == "false"
          $logger.info "checkbox " + str + " is not checked."
          errTest = 1
        else
          $logger.info "checkbox " + str + " is checked."
        end
      end
    end 
    link(:id,/#{$app.btnCancel}/).click
    return errTest
  end
  ## ====================================
  def verifyEditAlertsEditSave(errTest,netBuilder1, userType)
    alertDefault = Alert.new(netBuilder1,$qa_server.get_hash_from_db('Alerts',"alert_default"), $timeStamp)
    alertChange = Alert.new(netBuilder1,$qa_server.get_hash_from_db('Alerts',"alert_change"), $timeStamp)
    alertCharacters = Alert.new(netBuilder1,$qa_server.get_hash_from_db('Alerts',"alert_characters"), $timeStamp)
    alertSpecialChar = Alert.new(netBuilder1,$qa_server.get_hash_from_db('Alerts',"alert_specialChar"), $timeStamp)
    alertSmallerThanZero = Alert.new(netBuilder1,$qa_server.get_hash_from_db('Alerts',"alert_SmallerThanZero"), $timeStamp)
    alertZero  = Alert.new(netBuilder1,$qa_server.get_hash_from_db('Alerts',"alert_Zero"), $timeStamp)
    alertGreaterThan = Alert.new(netBuilder1,$qa_server.get_hash_from_db('Alerts',"alert_greaterThan"), $timeStamp)
    alertMax = Alert.new(netBuilder1,$qa_server.get_hash_from_db('Alerts',"alert_max"), $timeStamp)  
    setTextValueAlerts(alertChange)       
    if userType == 'CSUser'
      $app = EditAlertsAccMng.new
      link(:id,/#{$app.linkSaveButtonId}/).click
      sleep 10  * GlobalAdjustedSleepTime  
      $app = EditUser.new
      link(:id,/#{$app.btnEditAlerts}/).click
      sleep 10  * GlobalAdjustedSleepTime
      $app = EditAlertsAccMng.new  
    elsif userType == 'NetworkManager' || userType == 'NetworkUser'
      $app = EditAlertsUsers.new
      link(:id,/#{$app.linkSaveButtonId}/).click
      sleep 10  * GlobalAdjustedSleepTime 
      $app = UsersNB.new
      myTableBody = div(:id, /#{$app.tblNetworkUsers}/).table(:index, 1)
      myRow = findExactRow(myTableBody, 'User', netBuilder1.name)  #'ATNB_1_20110122_153026') #
      myRow.link(:text =>'Actions', :index => 1).click
      link(:id,/#{$app.actionsEditAlerts}/).click
      sleep 10  * GlobalAdjustedSleepTime
      $app = EditAlertsUsers.new 
    elsif userType == 'NetworkBuilder'
      $app = EditAlertsUsers.new
      link(:id,/#{$app.linkSaveButtonId}/).click
      sleep 10  * GlobalAdjustedSleepTime 
      $app = PreferencesTab.new
      link(:id,/#{$app.linkEditAlertId}/).click
      sleep 10  * GlobalAdjustedSleepTime
      $app = EditAlertsUsers.new   
    end 
    VerifyTextValueAlerts(alertChange) 
    setTextValueAlerts(alertCharacters)
    VerifyTextValueAlerts(alertChange)
    setTextValueAlerts(alertSpecialChar)
    VerifyTextValueAlerts(alertChange)
    setTextValueAlerts(alertSmallerThanZero)
    VerifyTextValueAlerts(alertZero)
    setTextValueAlerts(alertGreaterThan)
    VerifyTextValueAlerts(alertMax)
    return errTest
  end
  ## ====================================
  def getPubPassword(name)
    outlook = AdifyOutlook.new
    counter = 1
    pwd = ""
    begin
      sleep 20  * GlobalAdjustedSleepTime
      $logger.info "Waiting for publisher's password #{20 * counter } sec"
      counter += 1
      pwd  = outlook.getPublishersPassword  name
    end until pwd or counter > 12
    if pwd
      $logger.testcase("Temporary password for publisher is <#{pwd}> ",0)
    else
      $logger.testcase("Unable to get temporary password for publisher pwd: <#{pwd}> ",0)
    end
    return pwd
  end
  ## ====================================
  def getNetUserPassword(name)
    outlook = AdifyOutlook.new
    counter = 1
    begin
      sleep 20  * GlobalAdjustedSleepTime
      $logger.info "ing for network user password #{20 * counter } sec"
      counter += 1
      pwd  = outlook.getNetworkUserPassword  name
    end until pwd or counter > 12
    if pwd
      $logger.testcase("Temporary password for network user is <#{pwd}> ",0)
    else
      $logger.testcase("Unable to get temporary password for network user pwd: <#{pwd}> ",0)
    end
    return pwd
  end
  ## ====================================
  def getPasswordAndUpdateSignIn(name,publisher1,isPublisher)
    if isPublisher
      pwd = getPubPassword(name)
    else
      pwd = getNetUserPassword(name)
    end
    @ie.wait #sleep 10  * GlobalAdjustedSleepTime
    login(publisher1.name, pwd)
    @ie.wait #sleep 10  * GlobalAdjustedSleepTime
    $app = UpDateSignIn.new
    fill_out_UpdateSignIn(publisher1)
    @ie.wait #sleep 10
    return publisher1
  end
  ## ====================================
  def verifyAccountInfo()
    errCode = 0
    ##---------verify Account object is existing in the PreferenceAccountTab
    $app = PubAccountPreferenceAccountTab.new
    errCode = link_exists(":text",$app.name)
    link(:text,$app.name).click
    link(:id,/#{$app.editCon}/,9010).click  
    @ie.wait 
    edit_contactDetails
    @ie.wait 
    ##--------verify Contact Info is updated-------###
    $app = PubAccountPreferenceAccountTab.new
    @ie.wait # sleep 5
    fn = getSpanValue($app.uFirstName)
    ln = getSpanValue($app.uLastName)
    email = getSpanValue($app.uEmailAddress)
    phoneNm = getSpanValue($app.uPhoneNumber)
    cmpy = getSpanValue($app.uCompany)
    add1 = getSpanValue($app.uAddress1)
    add2 = getSpanValue($app.uAddress2)
    city = getSpanValue($app.uCity)
    state =getSpanValue($app.uState)
    zip = getSpanValue($app.uZipCode)
    $logger.info "successfully updated Contactinfo"
    ##-----verify edit prreferences--------
    @ie.wait
    link(:id,/#{$app.editPre}/,9011).click    
    @ie.wait #sleep 5
    edit_preferencesinfo
    @ie.wait 
    ##------verify defaultlanguage is updated--------##
    $app = PubAccountPreferenceAccountTab.new
    fn = getSpanValue($app.uDefaultLanguage)
    if fn == "English"
      puts "Test is successful"
      $logger.testcase("Defaultlanguage updated",0)
    else
      puts "Test failed"
      $logger.testcase("Defaultlanguag does't update",1)
    end
    ### Verify Time Zone is editable
    $app = PubAccountPreferenceAccountTab.new
    link(:text,$app.name,9015).click         #       $app = PubAccountPreferenceEditTimeZone.new
    option = select_list(:id,/#{$app.sTimeZone}/).getAllContents
    select_list(:id,/#{$app.sTimeZone}/).select option[3]
    $logger.info "----for change password refer adifyAccountsTest 4673,74----"
    return errCode
  end
  ## ====================================
  def verifyBillingInfo()
    ##---------verify Billing object is existing in the  AccountPreferences
    $app = PubAccountPreferenceBillingTab.new
    errCode = link_exists(":text",$app.name)
    ##----Edit Billing details-----##
    @ie.wait 
    $app = PubAccountPreferenceBillingTab.new
    link(:text,$app.name).click
    link(:id,/#{$app.eBillingMethod}/,9012).click
    $app = PubAccountPreferenceeditBillingMethod.new
    edit_Billingmethod
    return errCode
  end
  
  def verifyPayoutInfo()
    $app= PubAccountPreferencePayoutTab.new
    errCode = link_exists(":text",$app.name)
    ##-------Edit payoutmethod
    $app = PubAccountPreferencePayoutTab.new
    link(:text, $app.name).click
    link(:id,/#{$app.editPayoutMethod}/,9013).click #   $app = PubAccountPreferenceEditPayoutMethod.new
    @ie.wait #sleep 6
    edit_payoutmethod
    return errCode
  end
  ## ====================================
  def verifyVatInfo()
    errCode =0
    ##----Verify Vat tab for non US users
    $app = PubAccountPreferenceVatTab.new
    errCode = link_exists(':text',$app.name)
    if errCode == 0
      $app = PubAccountPreferenceVatTab.new
      link(:text,$app.name,9009).click #$app.PubAccountPreferenceEditVatContactInfo.new
      link(:id,/#{$app.editVatContact}/).click
      @ie.wait #sleep 5
      radio(:id,/#{$app.sNoBtnId}/).set
      link(:id,/#{$app.lSaveBtnId}/).click
      @ie.wait #sleep 5
    else
      errCode =1
    end
    return errCode
  end
  ## ====================================
  def verifyW9Info()
    ## verify W-9 object is existing in the PreferenceW9Tab
    $app= PubAccountPreferenceW9Tab.new
    errCode = link_exists(":text",$app.name)
    ##----------Edit W-9
    @ie.wait
    $app = PubAccountPreferenceW9Tab.new
    link(:text, $app.name).click
    link(:id,/#{$app.editW9}/,9004).click    
    edit_w9TaxInfo
    return errCode
  end
  ## ====================================
  def verifyAccountInfoImpersonate()
    $app = CSImpAccountPreferenceAccountTab.new
    errCode = link_exists(":text",$app.name)
    $app = CSImpAccountPreferenceAccountTab.new
    link(:text,$app.name).click
    link(:id,/#{$app.editCon}/,9204).click      
    @ie.wait #sleep 15
    edit_contactDetails
    $app = CSImpAccountPreferenceAccountTab.new
    link(:text,$app.name).click
    wait 
    link(:id,/#{$app.editPre}/,9205).click    
    @ie.wait
    edit_preferencesinfo
    return errCode
  end
  ## ====================================
  def verifyBillingInfoImpersonate()
    $app = CSImpAccountPreferenceBillingTab.new
    errCode = link_exists(":text",$app.name)
    $app = CSImpAccountPreferenceBillingTab.new
    link(:text,$app.name).click
    link(:id,/#{$app.eBillingMethod}/,9207).click  
    edit_Billingmethod
    return errCode
  end
  ## ====================================
  def verifyPayoutInfoImpersonate()
    $app = CSImpAccountPreferencePayoutTab.new
    errCode = link_exists(":text",$app.name)
    $app = CSImpAccountPreferencePayoutTab.new
    link(:text, $app.name).click
    link(:id,/#{$app.editPayoutMethod}/,9211).click  
    edit_payoutmethod
    return errCode
  end
  ## ====================================
  def verifyW9InfoImpersonate()
    $app = PubAccountPreferenceW9Tab.new
    errCode = link_exists(":text",$app.name)
    $app = CSImpAccountPreferenceW9Tab.new
    link(:text, $app.name).click
    link(:id,/#{$app.editW9}/,9213).click   
    @ie.wait
    edit_w9TaxInfo
    return errCode
  end
  ## ====================================
  def verifyVatInfoImpersonate()
    $app = CSImpAccountPreferenceVatTab.new
    errCode = link_exists(":text",$app.name)
    $app = CSImpAccountPreferenceVatTab.new
    link(:text,$app.name).click
    link(:id,/#{$app.editVatContact}/,9209).click  
    @ie.wait
    radio(:id,/#{$app.sNoBtnId}/).set
    link(:id,/#{$app.lSaveBtnId}/).click
    return errCode
  end
  ## ====================================
  def verifyNB_VATtab()
    $app = NBPreferencesVatTab.new
    errCode = link_exists(':text',$app.name)
    if errCode == 0
      $logger.testcase("VAT Link exists",0)
      $app = NBPreferencesVatTab.new
      link(:text,$app.name).click
      link(:id,/#{$app.editVatContact}/,206).click 
      radio(:id,/#{$app.sNoBtnId}/).set
      link(:id,/#{$app.lSaveBtnId}/).click
    else
      errCode=1
    end
    return errCode
  end
  ## ====================================
  def set_adspace_name(adspace_name)
    t = get_table_from_div($app.divAdSpacesTableId)
    row_to_fill = find_row(t, 'Name', "click to edit")
    dialog_text_field_set(row_to_fill.cell(:class,/#{$app.tdNameClass}/),adspace_name,"ad space name")
  end
  ## ====================================
  def set_adspace_description(adspace_description)
    t = get_table_from_div($app.divAdSpacesTableId)
    row_to_fill = find_row(t, 'Description', "click to edit")
    dialog_text_field_set(row_to_fill.cell(:class,/#{$app.tdDescriptionClass}/),adspace_description,"ad space description")
  end
  ## ====================================
  def set_adspace_size(adspace_size)
    t = get_table_from_div($app.divAdSpacesTableId)
    row_to_fill = find_row(t, 'Size', "Select size")
    dialog_select_list_set(row_to_fill.cell(:class,/#{$app.tdSizeIdClass}/),adspace_size, "ad space size") 
  end
  ## ====================================
  def set_adspace_domain(adspace_domain)
    t = get_table_from_div($app.divAdSpacesTableId)
    row_to_fill = find_row(t, 'Site domain', "click to edit")
    dialog_text_field_set(row_to_fill.cell(:class,/#{$app.tdSiteDomainClass}/),adspace_domain, "ad space domain")
  end
  ## ====================================
  def set_adspace_page_position(adspace_page_position)
    t = get_table_from_div($app.divAdSpacesTableId)
    row_to_fill = find_row(t, 'Page position', "Top Center")
    dialog_select_list_set(row_to_fill.cell(:class,/#{$app.tdPagePositionClass}/),adspace_page_position, "ad space page position")
  end
  ## ====================================
  def set_adspace_click_location(adspace_click_location)
    t = get_table_from_div($app.divAdSpacesTableId)
    row_to_fill = find_row(t, 'Click location', "New Window")
    dialog_select_list_set(row_to_fill.cell(:class,/#{$app.tdClickLocationClass}/), adspace_click_location, "ad space click location")
  end
  ## ====================================
  def set_adspace_third_party_url(adspace_3rd_party_url)
    t = get_table_from_div($app.divAdSpacesTableId)
    row_to_fill = find_row(t, 'Third-party tracking URL',  "click to edit")
    dialog_text_field_set(row_to_fill.cell(:class,/#{$app.tdThirdPartyURLClass}/),adspace_3rd_party_url, "ad space third party url")
  end
  ## ====================================
  def set_ad_name(ad_name)
    table_ad = div(:id,/#{$app.divAdTableId}/).tables[0]
    row_to_fill = find_row(table_ad, 'Name','Click to edit')
    dialog_text_field_set(row_to_fill.cell(:class,/Name/),ad_name,"ad name")
  end
  ## ====================================
  def set_ad_size(ad_size)
    table_ad = div(:id,/#{$app.divAdTableId}/).tables[0]
    row_to_fill = find_row(table_ad, 'Size','Click to select')
    dialog_select_list_set(row_to_fill.cell(:class,/Size/),ad_size,"ad size")
  end
  ## ====================================
  def set_ad_destination_url(ad_destination_url)
    table_ad = div(:id,/#{$app.divAdTableId}/).tables[0]
    row_to_fill = find_row(table_ad, 'Destination URL','http://www.nourl.com')
    dialog_text_field_set(row_to_fill.cell(:class,/Destination/),ad_destination_url,"ad destination")
  end
  ## ====================================
  def set_ad_code(ad_code)
    table_ad = div(:id,/#{$app.divAdTableId}/).tables[0]
    row_to_fill = find_row(table_ad, 'Code','Click to edit')
    dialog_text_area_set(row_to_fill.cell(:class,/Code/),ad_code,"ad code")
  end
  def set_ad_attribute_none
    table_ad = div(:id,/#{$app.divAdTableId}/).tables[0]
    row_to_fill = find_row(table_ad, 'Attributes','Click to select')
    if row_to_fill.exists?
      row_to_fill.cell(:class,/Attributes/).click
      sleep 2
      checkbox(:id,/AttributesDialogNoneApply/).set
      link(:id,/AttributesDialog_Save/).click
      sleep 3
    end
  end
  ### =============================================================================
  # private
  def get_table_from_div(div_id)
    30.times{ break if div(:id,/#{div_id}/).exists?; sleep 1  * GlobalAdjustedSleepTime}
    t= div(:id,/#{div_id}/).tables.find{|t| t.rows.length > 1 }
  #  return div(:id,/#{div_id}/).tables.find { |t|  t.row_count > 1 }
   return t
  end
  
  ## ========================================================
  ## ========================== vlad ======================== 
  ## ======================================================== 
 def click_sites_tab(name)
 $SitesTab = "ctl00_appHeader_topTabs"   ## ctl00_appHeader_topTabs_ctl00
 n=0
   while n <= NubmerLoops
    sleep LoopSleep
    n=n+1
    ##>> k=n.to_f/10
    ##>> puts ('sites tab: time = '+k.to_s + ' seconds  ') + (' n = '+n.to_s + ' time') 
     break if div(:id => $SitesTab).link(:text => "#{name}").visible?  ## .visible  text.include?  exists
   end 
   div(:id => $SitesTab).link(:text => "#{name}").click
   $logger.info "Tab #{name} has been clicked" 
   
 end ## click_sites_tab
 
 def sites_select_radio(name)  ##  vvv
       $RadioButton1 = name  ## radioRTB  radioAll  radioDeal   radioStandard
       n=0
       while  n <= NubmerLoops 
        sleep  LoopSleep
        n=n+1
        break if radio(:id, $RadioButton1).exists?
       end 
       ## puts "RTB selected: " + radio(:id, $RadioButton1).set?.to_s
         radio(:id, $RadioButton1).set
         $logger.info "Campaign type radio button: #{name} has been selected"  
  end

 def campaign_search_text(search_text)
 $CampaignSearchField = "ctl00_BodyContent_CampaignListSearchTerms"
  n=0
   while  n <= NubmerLoops
    sleep LoopSleep
    n=n+1
     break if text_field(:id, $CampaignSearchField).exists?  
   end
   text_field(:id, $CampaignSearchField).set(search_text) 
   $logger.info "Search campaign: #{search_text} has been set"
 end 
 
 def campaign_click_search()
   $CampaignSearchButton = "ctl00_BodyContent_CampaignListSearchButton"   ### vvv fail
   
   n=0
   while  n <= NubmerLoops
    sleep LoopSleep
    n=n+1
     break if button(:id, $CampaignSearchButton).exists?  
   end 
   button(:id, $CampaignSearchButton).click
   $logger.info "Search campaign button has been clicked"
end

def campaign_name_click(name)
      $CampaignNameLink = name
     n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        break if link(:text,/#{$CampaignNameLink}/).exists? 
       end 
         link(:text, /#{$CampaignNameLink}/).click
         $logger.info "Campaign name: #{name} has been clicked"
end 
 
 def click_platformtools_link(name)
  $PlatformTools = "ctl00_appHeader_topTabs_ctl00"
  n=0
   while  n <= NubmerLoops
    sleep LoopSleep
    n=n+1
     break if div(:id => $PlatformTools).li(:text,name).exists?  
   end 
   div(:id => $PlatformTools).li(:text,name).click 
   $logger.info "Link #{name} has been clicked" 
 end ## click_platformtools_tab
 
 def lineitem_click_location()
        $CellLocation = /Location/
        n=0
        while  n <= NubmerLoops 
        sleep  LoopSleep
        n=n+1
          break if td(:class, $CellLocation).link(:text, "edit").exists?
        end 
       td(:class, $CellLocation).span(:class, "adifyButton actionButton").click 
       ## td(:class, $CellLocation).link(:text, "edit").click
       $logger.info "Location cell has been clicked"
end  

def location_click_editadspaces()  ##  delete vvv
     $EditAdSpacesButton = "ctl00_InstructionContent_LocationSelector_EditSpaces"
     n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        break if link(:id,$EditAdSpacesButton).exists? 
       end 
       link(:id,$EditAdSpacesButton).click
       $logger.info "Edit ad spaces button has been clicked"
end
def lineitem_click_editadspaces()
       $AdSizeEdit = /AdSizes/
       n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        break if td(:class,$AdSizeEdit).link(:text, "edit").exists? 
        ##  puts "Size cell"
        ##  break
        ## else
        end 
        ## td(:id,$AdSizeEdit).span(:class, "adifyButton actionButton").click 
        td(:class,$AdSizeEdit).link(:text, "edit").click
        $logger.info "Edit ad spaces cell has been clicked"
end 

def networklocation_select_radiobutton(index)
        $LineItemLocation = "ctl00_InstructionContent_LocationSelector_LocationTypeList_" ## 0,1,2,3,4
        n=0
       while  n <= NubmerLoops 
        sleep LoopSleep * 5
        n=n+1
        break if radio(:id, $LineItemLocation + index).exists?
       end 
         ## radio(:id, $LineItemLocation + "2").set  ## reset radio button
         ## sleep 3
         radio(:id, $LineItemLocation + index).set
         $logger.info "Network location radio button: #{index} has been selected"
end 
def location_savechanges_click(button)  ##  vvv
      $SaveCampaignLineItem = "ctl00_BodyContent_SaveButton"
     n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        break if link(:id,$SaveCampaignLineItem).exists? 
       end 
         link(:id,$SaveCampaignLineItem).click
         $logger.info "Save location button has been clicked"
         
       $SpinImage = /ThemeImage/   ## "ctl00_BodyContent_ThemeImage1"
       m=0
       while m <= 15
       sleep LoopSleep
       m=m+1
        if image(:id, $SpinImage).exists?
          else
          break
        end
       end
end

def location_click_editsites()
     $EditSitesButton = "ctl00_InstructionContent_LocationSelector_EditSites"
     n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        break if link(:id,$EditSitesButton).exists? 
       end 
       link(:id,$EditSitesButton).click
       $logger.info "Edit sites button has been clicked"
end

def savedialog_click_save()
     $SaveButton = "ctl00_InstructionContent_LocationSelector_SaveDialog_Save"
     $SpinImage = /ThemeImage/ 
     ## sleep 1 ## vvv
     n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        break if link(:id,$SaveButton).exists? 
       end 
       link(:id,$SaveButton).click
       $logger.info "Save button on pup up has been clicked"
       sleep LoopSleep * 5
       m=0
       while m <= 15
       sleep LoopSleep
       m=m+1
       break if !image(:id, $SpinImage).exists? 
        ## puts "Go live image"
        ## else
        ##  break
        ## end 
       end
end  ### v-v-v

def lineitems_chooseads_select()
      ##$CheckBox = "ctl00_DialogContent_LineItemCreativesDialog_LineItemEditCreativesControl_BannerAdTable_CheckState_hcb"
      $CheckBox = "ctl00_DialogContent_LineItemCreativesDialog_LineItemEditCreativesControl_MixedAdTable_CheckState_hcb"
       n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
         break if checkbox(:id,$CheckBox).exists? 
        if checkbox(:id,$CheckBox).exists?
          break
         else
           $logger.info "Check box select all ads does not exist" 
        end
       end 
            
       if checkbox(:id,$CheckBox).set? == false ## unchecked
         checkbox(:id,$CheckBox).set
       elsif
         checkbox(:id,$CheckBox).set? == true ## checked
         checkbox(:id,$CheckBox).clear
       end 
       $logger.info "Check box select ads has been clicked"
end  

 def enter_search_text (search_text)
 $SitesSearchEdBox = "ctl00_BodyContent_SiteTableSearchBox"
  n=0
   while  n <= NubmerLoops
    sleep LoopSleep
    n=n+1
     break if text_field(:id, $SitesSearchEdBox).exists?  
   end
   text_field(:id, $SitesSearchEdBox).set(search_text)
   $logger.info "Entered text #{search_text} for the search"  
 end
 
 def sites_click_search()
   $SitesSearchButton = "ctl00_BodyContent_SiteTableSearchButton"
   n=0
   while  n <= NubmerLoops
    sleep LoopSleep
    n=n+1
     break if button(:id, $SitesSearchButton).exists?  
   end 
   button(:id, $SitesSearchButton).click
   $logger.info "Search button has been clicked"  
 end  

def sites_click_actions
    $MenuActions = '//tr[1]/td[3]/div/span/span/a/img'
    ## '//td[3]/div/span/span/a/em'  '//tr[1]/td[3]/div/span/span/a/img'   #// '//tr[" + 1.to_s + "]/td[3]/div/span/span/a/img'    "//tr[15]/td[3]/div/span/span/a/img"  vvv   "  >> '
    #$MENUACTIONSXP = "//tr[" + current_rows.to_s + "]/td[3]/div/span/span/a/img"  
     n=0
     sleep 2
     while  n <= NubmerLoops
      sleep LoopSleep
      n=n+1
       break if image(:xpath, $MenuActions).exists?   
     end 
     image(:xpath, $MenuActions).click 
     $logger.info "Actions drop down menu has been clicked"     
end

def sites_select_menu_actions
  $MenuItemRemove = "ctl00_BodyContent_SiteActionButton_RemoveSite"
       n=0
     while  n <= NubmerLoops
      sleep LoopSleep
      n=n+1
       break if element(:id, $MenuItemRemove).exists?  
     end  
     element(:id, $MenuItemRemove).click 
     $logger.info "Remove site from network has been selected"  
end

def sites_click_yes
  $YesButton = "ctl00_DialogContent_RemoveSiteDialog_Yes"
  ## No button: # ctl00_DialogContent_RemoveSiteDialog_No 
     n=0
     while  n <= NubmerLoops
      sleep LoopSleep
      n=n+1
      break if element(:id,$YesButton).exists?  
     end 
     element(:id,$YesButton).click
     $logger.info "Yes, remove button has been clicked"  
end  

def sites_cleanup_sitestable ()
    $SitesTable = "ctl00_BodyContent_SiteTable"
    $SpinImage = "ctl00_BodyContent_ThemeImage1"
    $logger.info "Starting to clean up sites table"  
    sleep LoopSleep * 5
     m=0
     while m <= 5
     sleep LoopSleep
     m=m+1
      break if !image(:id, $SpinImage).exists? 
     end
     n=0
     while  n <= NubmerLoops
      sleep LoopSleep * 5
      n=n+1
      break if get_table_from_div($SitesTable).exists?  
     end 
     @table = get_table_from_div($SitesTable).trs.length  
      _counter = 0
      if @table > 0
        until  _counter >= @table - $Number_Sites - 1 do 
         sites_click_actions        ####
         sites_select_menu_actions  ####
         sites_click_yes            ####
         sleep 3
         sites_click_search()       #### 
         _counter = _counter + 1
        end      
      end
end

def sales_createnewdeal_click
  $CreateNewDealButton = "ctl00_BodyContent_CreateDealMenuButton_Button"
     n=0
     while  n <= NubmerLoops
        sleep LoopSleep
        n=n+1
        break if element(:id,$CreateNewDealButton).exists?  
     end 
     link(:id,$CreateNewDealButton).click
     $logger.info "Create new deal button has been clicked"    
end

def sales_createnewcampaign_click
  $CreateNewCampaignButton = "ctl00_BodyContent_CreateCampaignMenuButton_Button"
     n=0
     while  n <= NubmerLoops
        sleep LoopSleep
        n=n+1
        break if element(:id,$CreateNewCampaignButton).exists?  
     end 
     link(:id,$CreateNewCampaignButton).click
     $logger.info "Create new campaign button has been clicked"    
end

def sales_select_dealtype(dealtype)
  $SelectDeal = "ctl00_BodyContent_CreateDealMenuButton_Create"+dealtype
     n=0
     while  n <= NubmerLoops 
      sleep LoopSleep
      n=n+1
      break if element(:id,$SelectDeal).exists?  
     end 
     link(:id,$SelectDeal).click
     $logger.info "Create #{dealtype} menu item has been selected"  
end

def sales_select_campaigntype(type) ##  ExtendedCampaign_d
  $SelectCampaign = "ctl00_BodyContent_CreateCampaignMenuButton_Create"+type  ## ctl00_BodyContent_CreateCampaignMenuButton_CreateExtendedCampaign_d
     n=0
     while  n <= NubmerLoops 
      sleep LoopSleep
      n=n+1
      break if link(:id,$SelectCampaign).exists?  
     end 
     link(:id,$SelectCampaign).click
     $logger.info "Create #{type} menu item has been selected"  
end

def sites_set_campaign_name(name)
     $DealName = "ctl00_BodyContent_clientTabView_campaignName"
     n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        break if element(:id,$DealName).exists?  
       end 
         text_field(:id,$DealName).set(name)
       $logger.info "Campaign name: #{name} has been set"
end  

def sites_set_campaign_description(description)
      $DealDescription = "ctl00_BodyContent_clientTabView_campaignDescription"
      n=0
       while  n <= NubmerLoops
        sleep LoopSleep
        n=n+1
        break if element(:id,$DealDescription).exists?  
       end 
         text_field(:id,$DealDescription).set(description)
         $logger.info "Campaign description #{description} has been set"
end
def sites_edit_network()
      $EditNetworkButton = "ctl00_BodyContent_clientTabView_targetNetworksButton"
      n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        break if link(:id,$EditNetworkButton).exists? 
       end 
         link(:id,$EditNetworkButton).click
         $logger.info "Edit button for Partner network(s) has been clicked" 
end

def select_network_set_network(networkID)
     $SetNetworkID = "ctl00_DialogContent_SelectNetworksDialog_ctl18"
     n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        break if text_field(:id,$SetNetworkID).exists? 
       end 
         text_field(:id, $SetNetworkID).set networkID
         $logger.info "Network ID: #{networkID} has been set for the search"
end

def select_network_click_search()
     $SearchButton = "ctl00_DialogContent_SelectNetworksDialog_SNSearchButton"
     n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        break if button(:id,$SearchButton).exists? 
       end 
         button(:id, $SearchButton).click
         $logger.info "Search button has been clicked"
end

def select_network_check_checkbox(networkID)
     $CheckBox = "ctl00_DialogContent_SelectNetworksDialog_SNDataTable_js_Chk_cb_" + networkID
     n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        break if checkbox(:id,$CheckBox).exists? 
       end 
         checkbox(:id, $CheckBox).set
         $logger.info "Check box for #{networkID} has been checked"
end

def select_network_click_buttonOK()
      $ButtonOK = "ctl00_DialogContent_SelectNetworksDialog_OK"
     n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        break if link(:id,$ButtonOK).exists? 
       end 
         link(:id, $ButtonOK).click
         $logger.info "Button OK has been checked"
end

def sales_select_salesrep(salesrep)
      $SalesRepList = "ctl00_BodyContent_clientTabView_CampaignResource_ddlSalesRep"+ salesrep
     n=0
       while  n <= NubmerLoops
        sleep LoopSleep
        n=n+1
        break if select_list(:id,$SalesRepList).exists? 
       end 
         select_list(:id, $SalesRepList).options[2].select
         $logger.info "Sales representive #{salesrep} has been selected"
end

def sales_click_savebutton()
 Watir.default_timeout = 360   
  
      $SaveButton = "ctl00_BodyContent_SaveButton"
     n=0
     $logger.info("Looking for a Save button") 
     puts "sales click save button " + Time.now.to_s  ## vvv
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        break if link(:id,$SaveButton).exists? 
       end 
         link(:id,$SaveButton).click
         $logger.info "Save button has been clicked"
         
       ##puts "sales click button " + Time.now.to_s  ## vvv 
       sleep 180 ## vvv
       ##puts "sleep " + Time.now.to_s  ## vvv 
       $SpinImage = /ThemeImage/   ## "ctl00_BodyContent_ThemeImage1"
       m=0
       while m <= NubmerLoops
       sleep LoopSleep
       m=m+1
       if image(:id, $SpinImage).exists?
         ## puts "Save campaign image" 
         ##puts Time.now 
          else
          break
         end
       end
       ##puts Time.now
  
end

def sales_click_savebutton_vvv()
      $Button = "ctl00_BodyContent_"
      $SaveButton = "SaveButton"
      $CancelButton = "CancelButton"
      
     n=0
       while  n <= NubmerLoops
        sleep LoopSleep
        n=n+1
        puts "Save " + n.to_s
        break if a(:id,$Button + $SaveButton).exists? 
       end 
         a(:id,$Button + $SaveButton).click
         $logger.info "Save button has been clicked - vvv"
         
       m=0
       while m <= NubmerLoops 
       sleep LoopSleep * 3
       m=m+1
       #if a(:id,$Button + $CancelButton).exists? 
        #puts "Save button  " + m.to_s 
         # else
          if !a(:id,$Button + $CancelButton).exists? 
            break
          end
       end
        puts "no button  " + m.to_s 
         
       #$SpinImage = /ThemeImage/   ## "ctl00_BodyContent_ThemeImage1"
       #m=0
       #while m <= 30
       #sleep LoopSleep
       #m=m+1
       #if image(:id, $SpinImage).exists?
        # puts "Save campaign image" + m.to_s 
         # else
          #break
           #puts "no image" + m.to_s 
         #end
       #end
end

def sales_primarygoal_click()
      $GoalButton = "ctl00_BodyContent_clientTabView_SuccessMetric_updatePrimaryGoalButton"
     n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        break if link(:id,$GoalButton).exists? 
       end 
         link(:id, $GoalButton).click
         $logger.info "Primary goal button has been clicked"
end

def sales_editgoal_save()
     $GoalSaveButton = "ctl00_BodyContent_clientTabView_SuccessMetric_SuccessMetricDialog_Save"
     n=0
       while  n <= NubmerLoops
        sleep LoopSleep
        n=n+1
       break if link(:id,$GoalSaveButton).exists? 
      end 
         link(:id, $GoalSaveButton).click
         $logger.info "Save goal button has been clicked"
 end

def campaign_click_lineitems(tab_name)
      $TabLineItems = "ctl00_BodyContent_clientTabView_ctl00"  ## ctl00_BodyContent_clientTabView_ctl00
      n=0
       while  n <= NubmerLoops 
        sleep  LoopSleep
        n=n+1
        if div(:id, $TabLineItems).link(:text, tab_name).exists?    ##  "Line Items"
          puts "Tab Line Items exists and number of loops: #{n}"
          break
        else
          puts "Tab Line Items does not exist and number of loops: #{n}" 
        end   
       end 
         sleep 3 ## vvv
         div(:id, $TabLineItems).link(:text, tab_name).click
         ##div(:id, $TabLineItems).span(:text, tab_name).click
         $logger.info "Tab #{tab_name} has been clicked"
                
       $SpinImage = /ThemeImage/   ## "ctl00_BodyContent_ThemeImage1"
       m=0
       while m <= 10  ## vvv
       sleep LoopSleep
       m=m+1
       if image(:id, $SpinImage).exists?
          else
          break
         end
       end
end

def campaign_click_newlineitem()   ###  vvv
     $ButtonNewLineItem = "ctl00_BodyContent_clientTabView_ButtonLineItemNew"  
      n=0
       while  n <= NubmerLoops 
        sleep  LoopSleep * 3
        n=n+1
        break if link(:id, $ButtonNewLineItem).exists? 
       end 
         link(:id, $ButtonNewLineItem).click
         $logger.info "New line item button has been clicked"
end

def campaign_click_dealname()
        $CellDealName = "Name"   ##  /#{$CellDealName}/
        n=0
       while  n <= NubmerLoops 
        sleep  LoopSleep
        n=n+1
        break if td(:class, /Name/).exists? 
       end 
         td(:class, /Name/).click 
         $logger.info "Deal name has been clicked"
end

def campaign_set_dealnameOLD(deal_name)
        ##$EditDealName = "yui-textboxceditor66-container"  ##   yui-textboxceditor62-container "yui-textboxceditor63-container"  -- ppe 
        $EditDealName = /yui-textboxceditor/
        $TypeText = "text"
        n=0
       while  n <= NubmerLoops 
        sleep  LoopSleep
        n=n+1
        if div(:id, $EditDealName).text_field(:type, $TypeText).visible? ## exists?
          break
        else
          puts "Deal name edit box is not visible"   ## vvv
        end  
       end
         ##text_field(:type, $TypeText).set deal_name 
         div(:id, $EditDealName).text_field(:type, $TypeText).set deal_name  
         div(:id, $EditDealName).button(:text, "OK").click 
         $logger.info "Deal: #{deal_name} has been set"  
end
def campaign_set_dealname(deal_name)
        ##$EditDealName = "yui-textboxceditor#{my}-container"  ##   yui-textboxceditor62-container "yui-textboxceditor66-container"  -- ppe 
        ##$EditDealName = /yui-textboxceditor/
        $TypeText = "text"
        n=0
      while  n <= NubmerLoops
        sleep  LoopSleep
        for j in 10..100
          k=j
            _editdealname = "yui-textboxceditor#{k.to_s}-container"
            if element(:id, _editdealname).text_field(:type, $TypeText).present? #exists? #visible? ## exists?
              $logger.info "Deal name text box ID: #{_editdealname} has been extracted" 
              $EditDealName = _editdealname
              n = NubmerLoops+2
              break
            else
            end
            break if n == NubmerLoops+2
         end
        end
         div(:id, $EditDealName).text_field(:type, $TypeText).set deal_name 
         div(:id, $EditDealName).button(:text, "OK").click 
         $logger.info "Deal name: #{deal_name} has been set"  
end



def campaign_click_bidderid()
        $CellBidderId = /proxyBidderId/
        n=0
       while  n <= NubmerLoops 
        sleep  LoopSleep
        n=n+1
        break if td(:class, $CellBidderId).exists? 
       end 
         td(:class, $CellBidderId).click 
        $logger.info "Bidder ID has been clicked"

def selectbidder_set_biddername(bidder)
        $SearchBidder = "ctl00_DialogContent_SelectBidderPopUpDialog_BidderSearchTextBox"
        n=0
       while  n <= NubmerLoops 
        sleep  LoopSleep
        n=n+1
        break if text_field(:id, $SearchBidder).exists? 
       end 
         text_field(:id, $SearchBidder).set bidder
         $logger.info "Bidder: #{bidder} has been set"
end

def selectbidder_click_search()
      $SearchButton = "ctl00_DialogContent_SelectBidderPopUpDialog_BidderSearchButtonId"
       n=0
       while  n <= NubmerLoops 
        sleep  LoopSleep
        n=n+1
        break if button(:id, $SearchButton).exists? 
       end 
      button(:id, $SearchButton).click
      $logger.info "Search bidder button has been clicked"
end

def selectbidder_click_radiobutton()
        ##$RadioButton = "rb_88" ##"rb_94" ##"rb_48"  ## name  rb_groupctl00_DialogContent_SelectBidderPopUpDialog_BidderDataTable
        $RadioButtonName = 'rb_groupctl00_DialogContent_SelectBidderPopUpDialog_BidderDataTable'
        n=0
       while  n <= NubmerLoops 
        sleep  LoopSleep
        n=n+1
        ##break if ie.radio(:id, $RadioButton).exists?
        break if radio(:name, $RadioButtonName).exists?
       end 
         _radiobuttonID = radio(:name, $RadioButtonName).id
         puts "Bidder radiobuttonID: #{_radiobuttonID}" 
         radio(:id, _radiobuttonID).set
         $logger.info "Select bidder radio button has been clicked"
end

def selectbidder_click_save()
       $SaveButton = "ctl00_DialogContent_SelectBidderPopUpDialog_Save"  
       n=0
       while  n <= NubmerLoops 
        sleep  LoopSleep
        n=n+1
        break if link(:id, $SaveButton).exists?
       end 
         link(:id, $SaveButton).click
         $logger.info "Save bidder button has been clicked"
         
       $SpinImage = /ThemeImage/   ## "ctl00_BodyContent_ThemeImage1"
       m=0
       while m <= 5
       sleep LoopSleep
       m=m+1
       if image(:id, $SpinImage).exists?
          else
          break
         end
       end
         
end

def campaign_click_dealid()
        $CellDealID = /DealID yui-dt-col-DealID/ ##/DealID/  yui-dt17-col-DealID yui-dt-col-DealID yui-dt-sortable yui-dt-resizeable yui-dt-editable yui-dt-selected
        n=0
       while  n <= NubmerLoops 
        sleep  LoopSleep
        n=n+1
        if td(:class, /DealID yui-dt-col-DealID/).exists?
          puts "DealID yui-dt-col-DealID --- exists" ## vvv
          break
         else
           puts "DealID yui-dt-col-DealID --- does not exists" ## vvv
         end  
       end 
         td(:class, /DealID yui-dt-col-DealID/).click 
         $logger.info "Cell with deal ID has been clicked"
end

def campaign_set_dealid(deal_id)
        #$EditDealID = "yui-textboxceditor58-container"  ## ppe 58   stg 62
        #$TypeText = "text"
        #n=0
       #while  n <= NubmerLoops 
        #sleep  LoopSleep
       # n=n+1
        #break if text_field(:type, $TypeText).exists?
       #end 
         #div(:id, $EditDealID).text_field(:type, $TypeText).set deal_id
         #div(:id, $EditDealID).button(:text, "OK").click   
         #$logger.info "Deal ID: #{deal_id} has been created"
     ###======================================= 
        ##$EditDealName = "yui-textboxceditor#{my}-container"  ##   yui-textboxceditor62-container "yui-textboxceditor66-container"  -- ppe 
        ##$EditDealName = /yui-textboxceditor/
        $TypeText = "text"
        n=0
      while  n <= NubmerLoops
        sleep  LoopSleep
        for j in 10..100
          k=j
            _editdealID = "yui-textboxceditor#{k.to_s}-container"
            if element(:id, _editdealID).text_field(:type, $TypeText).present? #exists? #visible? ## exists?
              $logger.info "Deal ID text box ID: #{_editdealID} has been extracted" 
              $EditDealID = _editdealID
              n = NubmerLoops+2
              break
            else
            end
            break if n == NubmerLoops+2
         end
        end
         div(:id, $EditDealID).text_field(:type, $TypeText).set deal_id 
         div(:id, $EditDealID).button(:text, "OK").click 
         $logger.info "Deal ID: #{deal_id} has been set"  
end

def campaign_select(name)    ###  remove vvv
            $RadioButton1 = name  ## radioRTB  radioAll  radioDeal   radioStandard
        n=0
       while  n <= NubmerLoops 
        sleep  LoopSleep
        n=n+1
        break if radio(:id, $RadioButton1).exists?
       end 
       puts radio(:id, $RadioButton1).set?
         radio(:id, $RadioButton1).set
         $logger.info "Campaign type radio button: #{name} has been selected"
  
end 
def campaign_select_radiobutton(type)   ##  campaigntype_select_radiobutton
          $RadioButton = type  ## radioRTB  radioAll  radioDeal   radioStandard
        n=0
       while  n <= NubmerLoops 
        sleep  LoopSleep
        n=n+1
        break if radio(:id, $RadioButton).exists?
       end 
         radio(:id, $RadioButton).set
         $logger.info "Campaign type radio button: #{type} has been selected"
end



def editsites_click_topcheckbox()
  $TopCheckBox = "ctl00_BodyContent_LocationRefiner_LocationTable_CheckState_hcb"
      n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        puts "Sleep for edit ad spaces check box - " + n.to_s
        break if checkbox(:id,$TopCheckBox).exists?
       end 
       sleep 1   ## vvv
       if checkbox(:id,"ctl00_BodyContent_LocationRefiner_LocationTable_CheckState_hcb").set? == false ## unchecked
         $logger.info("Check box edit ad spaces unchecked")  ##  vvv
        checkbox(:id,"ctl00_BodyContent_LocationRefiner_LocationTable_CheckState_hcb").set
        $logger.info "Check box edit ad spaces has been checked"
       elsif
        checkbox(:id,"ctl00_BodyContent_LocationRefiner_LocationTable_CheckState_hcb").set? == true ## checked
        $logger.info("Check box edit ad spaces checked")  ##  vvv
        checkbox(:id,"ctl00_BodyContent_LocationRefiner_LocationTable_CheckState_hcb").clear
        $logger.info "Check box edit ad spaces has been unchecked"
       end  
       
end  
def editsites_enter_sitename(sitename)   ###  edit sites and ad spaces   vvv
    $SearchEditBox = "ctl00_BodyContent_LocationRefiner_LocationTableSearchBox" ## "ctl00_BodyContent_LocationRefiner_LocationTableSearchBox"
      n=0
      sleep 2  ##  vvv
       while  n <= NubmerLoops * 5## vvv  6/2/17
        sleep LoopSleep * 5 ##  vvv
        n=n+1
        
        if text_field(:id,$SearchEditBox).exists?
         # puts "activate break: " + n.to_s
          break
        #else
        #  puts "enter sitename loop: " + n.to_s   ## vvv  
        end 
          ##break if text_field(:id,$SearchEditBox).exists? 
       end 
       text_field(:id,$SearchEditBox).set sitename  ## siteid
       $logger.info "Site name: #{sitename} has been set"
end  

def editsites_click_searchbutton()
      $SearchButton = "ctl00_BodyContent_LocationRefiner_LocationTableSearchButton"
      n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        break if button(:id,$SearchButton).exists? 
       end 
       button(:id,$SearchButton).click
       $logger.info "Search sites button has been clicked"
 end 
  

def lineitems_chooseads_save()
      $OkButton = "ctl00_DialogContent_LineItemCreativesDialog_Ok"  ## "ctl00_DialogContent_LineItemCreativesDialog_Cancel"
       n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        break if link(:id,$OkButton).exists? 
       end  
   link(:id, $OkButton).click 
   $logger.info "Save ads button has been clicked"
end
def lineitems_click_confirmlive()
        $ConfirmLiveButton = "ctl00_BodyContent_ConfirmButton" 
        $SpinImage = /ThemeImage/ 
       n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        break if link(:id, $ConfirmLiveButton).exists? 
       end  
   link(:id, $ConfirmLiveButton).click
   $logger.info "Confirm - Go Live button has been clicked"
     sleep LoopSleep * 5
     m=0
     while m <= 15
     sleep LoopSleep
     m=m+1
     break if !image(:id, $SpinImage).exists? 
      ## puts "Go live image"
      ## else
      ##  break
      ## end 
      end
end  

def confirmcampaign_click_golive()
       $GoLiveButton = "ctl00_BodyContent_LiveButton"  
       n=0
       while  n <= NubmerLoops 
        sleep LoopSleep
        n=n+1
        break if link(:id, $GoLiveButton).exists? 
       end  
       link(:id, $GoLiveButton).click
       $logger.info "Go Live button has been clicked"
end  
 

##   ie.link(:id, "ctl00_BodyContent_LiveButton").click
## ============ ##  button(:id,"ctl00_BodyContent_LocationRefiner_LocationTableSearchButton").click 
## ==================================================================
end ## class watir::IE

end