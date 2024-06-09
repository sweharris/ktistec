require "../framework/controller"

require "../models/relationship/content/follow/hashtag"
require "../models/task/fetch/hashtag"

class StreamsController
  include Ktistec::Controller

  get "/stream/tags/:hashtag" do |env|
    hashtag = env.params.url["hashtag"]
    if (first_count = Tag::Hashtag.all_objects_count(hashtag)) < 1
      not_found
    end
    env.response.content_type = "text/event-stream"
    collection = ActivityPub::Collection::Hashtag.find_or_create(name: hashtag)
    collection.subscribe do
      task = Task::Fetch::Hashtag.find(source: env.account.actor, name: hashtag)
      follow = Relationship::Content::Follow::Hashtag.find(actor: env.account.actor, name: hashtag)
      count = Tag::Hashtag.all_objects_count(hashtag)
      body = tag_page_tag_controls(env, hashtag, task, follow, count)
      stream_replace(env.response, id: "tag_page_tag_controls", body: body)
      if count > first_count
        first_count = Int64::MAX
        body = Ktistec::ViewHelper.refresh_posts_message(hashtag_path(hashtag))
        stream_prepend(env.response, selector: "section.ui.feed", body: body)
      end
    end
  end

  get "/stream/objects/:id/thread" do |env|
    id = env.params.url["id"].to_i
    unless (object = ActivityPub::Object.find?(id))
      not_found
    end
    thread = object.thread(for_actor: env.account.actor)
    first_count = thread.size
    env.response.content_type = "text/event-stream"
    collection = ActivityPub::Collection::Thread.find_or_create(thread: thread.first.thread)
    collection.subscribe do
      thread = object.thread(for_actor: env.account.actor)
      count = thread.size
      task = Task::Fetch::Thread.find?(source: env.account.actor, thread: thread.first.thread)
      follow = Relationship::Content::Follow::Thread.find?(actor: env.account.actor, thread: thread.first.thread)
      body = thread_page_thread_controls(env, thread, task, follow)
      stream_replace(env.response, id: "thread_page_thread_controls", body: body)
      if count > first_count
        first_count = Int64::MAX
        body = Ktistec::ViewHelper.refresh_posts_message(remote_thread_path(object))
        stream_prepend(env.response, selector: "section.ui.feed", body: body)
      end
    end
  end

  {% for action in %w(append prepend replace update remove before after morph refresh) %}
    def self.stream_{{action.id}}(io, body, id = nil, selector = nil)
      stream_action(io, body, {{action}}, id, selector)
    end
  {% end %}

  def self.stream_action(io : IO, body : String, action : String, id : String?, selector : String?)
    if id && !selector
      io.puts %Q|data: <turbo-stream action="#{action}" target="#{id}">|
    elsif selector && !id
      io.puts %Q|data: <turbo-stream action="#{action}" targets="#{selector}">|
    else
      raise "one of `id` or `selector` must be provided"
    end
    io.puts "data: <template>"
    body.each_line do |line|
      io.puts "data: #{line}"
    end
    io.puts "data: </template>"
    io.puts "data: </turbo-stream>"
    io.puts
    io.flush
  end
end
