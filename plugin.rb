# name: Blog Category
# about: Make a category feel more like a blog
# version: 0.0.1
# authors: Kyle Welsby <kyle@mekyle.com>

register_asset 'stylesheets/blog-like.scss'

after_initialize do
  require 'listable_topic_serializer'
  class ::ListableTopicSerializer
    def excerpt
      if object.excerpt.blank?
        cooked = object.first_post.pluck('cooked')
        excerpt = PrettyText.excerpt(cooked[0], 200, keep_emoji_images: true)
      else
        excerpt = object.excerpt
      end
      excerpt.gsub!(/(\[#{I18n.t 'excerpt_image'}\])/, '') if excerpt
      excerpt
    end

    def include_excerpt?
      object.excerpt.present?
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
end
