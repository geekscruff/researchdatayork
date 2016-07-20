# app/controllers/concerns/search_pure.rb
module CreateDip
  extend ActiveSupport::Concern

  included do
    # ???
    attr_reader :dip
  end

  def create_dip(dataset)
    @dip = dataset.aips[0]
  end

  def save_dip
    @dip.save
  end

  def update_dip(id, uuid)
    dataset = Dlibhydra::Dataset.find(id)
    @dip = dataset.aips[0]
    dip_info = get_dip_details(uuid)
    ingest_dip(dip_info['current_path'])
    set_dip_current_path(dip_info['current_path'])
    set_dip_uuid(dip_info['uuid'])
    set_dip_status(dip_info['status'])
    set_dip_current_full_path(dip_info['current_path'])
    set_dip_current_location(dip_info['current_location'])
    #set_dip_resource_uri(dip_info['resource_uri'])
    set_dip_package_size(dip_info['size'])
    #set_dip_origin_pipeline(dip_info['origin_pipeline'])
    save_dip

    'AIP updated with dissemination objects'
  end

  def set_dip_uuid(uuid)
    @dip.dip_uuid = uuid
  end

  def set_dip_current_path(value)
    @dip.dip_current_path = value
  end

  def set_dip_current_full_path(value)
    @dip.dip_current_full_path = value
  end

  def set_dip_package_size(value)
    @dip.dip_size = value
  end

  def set_dip_current_location(value)
    @dip.dip_current_location = value
  end

=begin
  def set_dip_origin_pipeline(value)
    @dip.origin_pipeline = value
  end
=end

  def set_dip_status(status)
    # TODO check vocab?
    @dip.dip_status = status
  end

  def set_first_requestor(value)
    @dip.first_requestor = value
  end

  # TODO capture folder structure
  def ingest_dip(dip_location)
    location = ENV['DIP_LOCATION'] + '/' + dip_location
    gw = Dlibhydra::GenericWork.new
    obj_fs = Hydra::Works::FileSet.new
    label = ''
    Dir.foreach(location) do |item|
      next if item == '.' or item == '..' or item == '.DS_Store'
      if item == 'objects'
        Dir.foreach(location + '/objects') do |object|
          # TODO is there more here I should exclude?
          next if object == '.' or object == '..' or object == '.DS_Store'
          gw.preflabel = object
          #obj_fs.preflabel = object
          label = object
          path = location + '/objects/' + object
          file1 = open(path)
          # this is the service file but doesn't appear to be supported in
          # https://github.com/projecthydra/hydra-works/blob/master/lib/hydra/works/models/concerns/file_set/contained_files.rb
          Hydra::Works::UploadFileToFileSet.call(obj_fs, file1)
          obj_fs.save
          gw.members << obj_fs
          gw.save
          @dip.members << gw
          save_dip
        end
      end
    end
    Dir.foreach(location) do |item|
      next if item == '.' or item == '..' or item == '.DS_Store'
      if item == 'objects'
        puts 'do nothing'
      elsif item == 'thumbnails'
        Dir.foreach(location + '/thumbnails') do |thumb|
          next if thumb == '.' or thumb == '..' or thumb == '.DS_Store'
          th_id = thumb.sub! '.jpg', ''
          puts th_id
          if label.include? th_id
            path = location + '/thumbnails/' + thumb + '.jpg'
            file = open(path)
            Hydra::Works::AddFileToFileSet.call(obj_fs, file,:thumbnail,update_existing: false)
            obj_fs.save
          end
        end
      elsif item == 'OCRfiles'
        Dir.foreach(location + '/OCRfiles') do |ocr|
          next if ocr == '.' or ocr == '..' or ocr == '.DS_Store'
          ocr_id = ocr.sub! '.txt', ''
          puts label
          puts ocr_id
          if label.include? ocr_id
            path = location + '/OCRfiles/' + ocr + '.txt'
            file = open(path)
            puts path
            Hydra::Works::AddFileToFileSet.call(obj_fs, file,:extracted_text,update_existing: false)
            obj_fs.save
          end
        end
      else
        next if item == '.' or item == '..' or item == '.DS_Store'
        fs = Hydra::Works::FileSet.new
        #fs.preflabel = item
        fs.save
        @dip.members << fs
        save_dip
        file = open(location + '/' + item)
        Hydra::Works::UploadFileToFileSet.call(fs, file)
        fs.save
      end
    end
    puts obj_fs.files

  end

  def get_dip_details(uuid)

    url = ENV['ARCHIVEMATICA_SS_URL']
    conn = Faraday.new(:url => url) do |faraday|
      faraday.request :url_encoded # form-encode POST params
      faraday.response :logger # log requests to STDOUT
      faraday.adapter Faraday.default_adapter # make requests with Net::HTTP
    end

    response = conn.get do |req|
      req.url '/api/v2/file/' + uuid + '/'
      req.headers['Accept'] = 'application/json'
    end
    JSON.parse(response.body)

  end

end