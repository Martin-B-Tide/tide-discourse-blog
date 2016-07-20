import TopicListItem from 'discourse/components/topic-list-item';

export default {
  name: 'blog-category',
  initialize(){
    TopicListItem.reopen({
      isBlogItem: function () {
        const topic = this.get('topic');
        return topic.get('category.fullSlug') == 'blog'
      }.property()
    })
  }
}
