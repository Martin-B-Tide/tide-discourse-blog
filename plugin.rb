# name: Blog Category
# about: Make a category feel more like a blog
# version: 0.0.2
# authors: Kyle Welsby <kyle@mekyle.com>

register_asset 'stylesheets/blog-like.scss'

after_initialize do
  Topic.register_custom_field_type('thumbnails', :json)
  @nil_thumbs = TopicCustomField.where(name: 'thumbnails', value: nil)
  if @nil_thumbs.length
    @nil_thumbs.each do |thumb|
      hash = { normal: '', retina: '' }
      thumb.value = ::JSON.generate(hash)
      thumb.save!
    end
  end

  module ListHelper
    class << self
      def create_thumbnails(id, image, original_url)
        normal = image ? thumbnail_url(image, 100, 100) : original_url
        retina = image ? thumbnail_url(image, 200, 200) : original_url
        thumbnails = { normal: normal, retina: retina }
        save_thumbnails(id, thumbnails)
        thumbnails
      end

      def thumbnail_url(image, w, h)
        image.create_thumbnail!(w, h) unless image.has_thumbnail?(w, h)
        image.thumbnail(w, h).url
      end

      def save_thumbnails(id, thumbnails)
        return unless thumbnails
        topic = Topic.find(id)
        Rails.logger.info "Saving thumbnails: #{thumbnails}"
        topic.custom_fields['thumbnails'] = thumbnails
        topic.save_custom_fields
      end
    end
  end

  require 'cooked_post_processor'
  class ::CookedPostProcessor
    def get_linked_image(url)
      max_size = SiteSetting.max_image_size_kb.kilobytes
      file = FileHelper.download(url, max_size, 'discourse', true)
      Rails.logger.info "Downloaded linked image: #{file}"
      Upload.create_for(@post.user_id, file, file.path.split('/')[-1], File.size(file.path))
    rescue => e
      Rails.logger.error e
      nil
    end

    def create_topic_thumbnails(url)
      local = UrlHelper.is_local(url)
      image = local ? Upload.find_by(sha1: url[/[a-z0-9]{40,}/i]) : get_linked_image(url)
      Rails.logger.info "Creating thumbnails with: #{image}"
      ListHelper.create_thumbnails(@post.topic.id, image, url)
    end

    alias original_update_topic_image update_topic_image
    def update_topic_image
      if @post.is_first_post?
        img = extract_images_for_topic.first
        Rails.logger.info "Updating topic image: #{img}"
        if img['src']
          url = img['src'][0...255]
          create_topic_thumbnails(url)
        end
      end
      original_update_topic_image
    end
  end

  require 'listable_topic_serializer'
  class ::ListableTopicSerializer
    alias original_excerpt excerpt
    def excerpt
      if defined?(category_id) && Category.select(:slug).find_by_id(category_id).try(:slug) == 'blog'
        max_length = 400
        cooked = object.first_post.cooked
        excerpt = PrettyText.excerpt(cooked, max_length, keep_emoji_images: true)
        excerpt.gsub!(/(\[#{I18n.t 'excerpt_image'}\])/, '') if excerpt
        excerpt
      else
        original_excerpt
      end
    end

    def include_excerpt?
      object.excerpt.present?
    end

    def thumbnails
      return unless object.archetype == Archetype.default
      thumbs = get_thumbnails || get_thumbnails_from_image_url
      thumbs
    end

    def include_thumbnails?
      Rails.logger.debug "THUMBNAIL #{thumbnails}"
      thumbnails.present? && thumbnails['normal'].present?
    end

    def get_thumbnails
      thumbnails = object.custom_fields['thumbnails']
      thumbnails = ::JSON.parse(thumbnails) if thumbnails.is_a?(String)
      thumbnails = thumbnails[0] if thumbnails.is_a?(Array)
      thumbnails.is_a?(Hash) ? thumbnails : false
    end

    def get_thumbnails_from_image_url
      image = Upload.get_from_url(object.image_url)
      ListHelper.create_thumbnails(object.id, image, object.image_url)
    rescue => e
      Rails.logger.error '**************************'
      Rails.logger.error '   THUMBNAIL ERROR'
      Rails.logger.error e
      Rails.logger.error '**************************'
    end
  end

  require 'topic_query'
  class ::TopicQuery
    def list_blog
      options = {
        order: 'created'
      }
      create_list(:latest, options)
    end
  end

  require 'topic_list_item_serializer'
  class ::TopicListItemSerializer
    attributes :thumbnails
  end

  require 'list_controller'
  class ::ListController
    alias original_latest latest
    def latest(options = nil)
      if params.key?(:category) && params[:category].casecmp('blog').zero?
        list_opts = build_topic_list_options
        list_opts.merge!(options) if options
        user = list_target_user
        list = TopicQuery.new(user, list_opts).list_blog
        list.more_topics_url = construct_url_with(:next, list_opts)
        list.prev_topics_url = construct_url_with(:prev, list_opts)
        @description = SiteSetting.site_description
        @rss = :latest
        filter_title = I18n.t('js.filters.latest.title', count: 0)
        @title = I18n.t('js.filters.with_category', filter: filter_title, category: Category.find(list_opts[:category]).name)
        respond_with_list(list)
      else
        original_latest(options)
      end
    end
  end

  TopicList.preloaded_custom_fields << 'thumbnails' if TopicList.respond_to? :preloaded_custom_fields
end
