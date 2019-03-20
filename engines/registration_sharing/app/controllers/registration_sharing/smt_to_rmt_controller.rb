require_dependency 'registration_sharing/application_controller'

module RegistrationSharing

  class SmtToRmtException < RuntimeError; end

  class SmtToRmtController < ApplicationController
    def regsvc
      unless check_ip
        render status: :forbidden, plain: 'Forbidden'
        return
      end

      xml = Nokogiri::XML(request.body.read)

      if params[:command] == 'shareregistration'
        return smt_share_registration(xml)
      elsif params[:command] == 'deltesharedregistration'
        return smt_delete_registration(xml)
      else
        raise SmtToRmtException, 'Command not supported'
      end
    rescue SmtToRmtException => e
      render status: :bad_request, plain: e.to_s
    end

    protected

    def check_ip
      allowed_ips = (Settings[:regsharing][:smt_allowed_ips] rescue [] || [])
      allowed_ips.include?(request.remote_ip)
    end

    def smt_share_registration(xml)
      xml.css('registrationData').each do |reg_data|
        reg_data.css('tableData').each do |table|
          table_name = table.attribute('table').value

          hash = table_to_hash(table)

          if table_name == 'Clients'
            save_system(hash)
          elsif table_name == 'Registration'
            save_registration(hash)
          else
            raise SmtToRmtException, 'Unknown table'
          end
        end
      end
    end

    def save_system(hash)
      %w[GUID SECRET].each do |key|
        raise "Missing parameter: #{key}" if hash[key].blank?
      end

      system = System.find_or_create_by(login: hash['GUID'])
      system.password = hash['SECRET']
      system.hostname = hash['HOSTNAME']
      system.last_seen_at = hash['LASTCONTACT']
      system.save!
    end

    def save_registration(hash)
      %w[GUID REGDATE PRODUCTID].each do |key|
        raise "Missing parameter: #{key}" if hash[key].blank?
      end

      product = Product.find_by(id: hash['PRODUCTID'])
      raise "Can't find product with ID #{hash['PRODUCTID']}" unless product

      system = System.find_or_create_by(login: hash['GUID'])

      activation = Activation.find_or_create_by(service_id: product.service.id, system_id: system.id)
      activation.created_at = hash['REGDATE']
      activation.save!
    end

    def table_to_hash(table)
      hash = {}
      table.css('entry').each do |el|
        hash[el.attribute('columnName').value] = el.attribute('value').value
      end

      table.css('foreign_entry').each do |el|
        captures = el.attribute('value').value.scan(/PRODUCTDATAID=(\d+)/)
        hash[el.attribute('columnName').value] = captures[0][0] if captures[0]
      end
      hash
    end

    def smt_delete_registration(xml)
      guid = xml.css('deleteRegistrationData guid')

      raise 'System GUID not found' unless guid

      system = System.find_by(login: guid.text)
      system.destroy if system
    end
  end
end
