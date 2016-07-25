import { registerUnbound } from 'discourse/lib/helpers'
import { default as computed } from 'ember-addons/ember-computed-decorators';

import TopicListItem from 'discourse/components/topic-list-item'

var renderUnboundPreview = function(thumbnails) {
  var previewUrl = window.devicePixelRatio >= 2 ? thumbnails.retina : thumbnails.normal
  return `<img class="thumbnail" src="${previewUrl}" onerror="this.onerror=null;this.src='';this.className='no-thumbnail';">`
}

export default {
  name: 'blog-category',
  initialize(){
    registerUnbound('blog-category-unbound', function(thumbnails) {
      return new Handlebars.SafeString(renderUnboundPreview(thumbnails))
    });
    TopicListItem.reopen({
      isBlogItem: function () {
        const topic = this.get('topic');
        return topic.get('category.fullSlug') == 'blog'
      }.property(),

      @computed()
      showThumbnail() {
        return this.get('topic.thumbnails')
      }
    })
  }
}
