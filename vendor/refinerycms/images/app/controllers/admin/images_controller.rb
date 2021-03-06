class Admin::ImagesController < Admin::BaseController

  include Admin::ImagesHelper

  crudify :image,
          :order => "created_at DESC",
          :sortable => false

  before_filter :change_list_mode_if_specified, :init_dialog

  def index
    search_all_images if searching?
    paginate_all_images

    if RefinerySetting.find_or_set(:group_images_by_date_uploaded, true)
      @grouped_images = group_by_date(@images)
    end
  end

  def new
    @image = Image.new if @image.nil?

    @url_override = admin_images_url(:dialog => from_dialog?)
  end

  # This renders the image insert dialog
  def insert
    self.new if @image.nil?

    @url_override = admin_images_url(:dialog => from_dialog?, :insert => true)

    if params[:conditions].present?
      extra_condition = params[:conditions].split(',')

      extra_condition[1] = true if extra_condition[1] == "true"
      extra_condition[1] = false if extra_condition[1] == "false"
      extra_condition[1] = nil if extra_condition[1] == "nil"
    end

    find_all_images(({extra_condition[0].to_sym => extra_condition[1]} if extra_condition.present?))
    search_all_images if searching?

    paginate_images

    render :action => "insert"
  end

  def create
    @images = []
    begin
      unless params[:image].present? and params[:image][:image].is_a?(Array)
        @images << (@image = Image.create(params[:image]))
      else
        params[:image][:image].each do |image|
          @images << (@image = Image.create(:image => image))
        end
      end
    rescue Dragonfly::FunctionManager::UnableToHandle
      logger.warn($!.message)
      @image = Image.new
    end

    unless params[:insert]
      if @images.all?{|i| i.valid?}
        flash.notice = t('refinery.crudify.created', :what => "'#{@images.collect{|i| i.title}.join("', '")}'")
        unless from_dialog?
          redirect_to :action => 'index'
        else
          render :text => "<script>parent.window.location = '#{admin_images_url}';</script>"
        end
      else
        self.new # important for dialogs
        render :action => 'new'
      end
    else
      if @images.all?{|i| i.valid?}
        @image_id = @image.id if @image.persisted?
        @image = nil
      end
      self.insert
    end
  end

protected

  def init_dialog
    @app_dialog = params[:app_dialog].present?
    @field = params[:field]
    @update_image = params[:update_image]
    @thumbnail = params[:thumbnail]
    @callback = params[:callback]
    @conditions = params[:conditions]
  end

  def paginate_images
    @images = @images.paginate(:page => (@paginate_page_number ||= params[:page]),
                               :per_page => Image.per_page(from_dialog?, !@app_dialog))
  end

  def restrict_controller
    super unless action_name == 'insert'
  end

  def store_current_location!
    super unless action_name == 'insert' or from_dialog?
  end

end
