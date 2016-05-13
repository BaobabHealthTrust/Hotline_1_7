class HomeController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def index
    render :layout => false

    if !session[:tag_encounters].blank?
      Encounter.feed_tags(session[:tagged_encounters_patient_id])
      session.delete(:tag_encounters)
      session.delete(:tagged_encounters_patient_id)
    end

    session.delete(:end_call) if session[:end_call].present?
    session.delete(:no_guardian) if session[:no_guardian].present?
  end

  def configuration
    render :layout => false
  end
    
  def reference_material
    @material = Publify.find_by_sql("SELECT * FROM contents c WHERE c.type = 'Article'")
    render :layout => false
  end

  def reference_article
    @article = Publify.find_by_sql("SELECT * FROM contents c WHERE c.type = 'Article' AND id = #{params[:article_id]}").first
    render :layout => false
  end

  def concept_sets
    search_string = params[:search_string] || ''
    @names = ConceptName.where("name LIKE '%#{search_string}%'").select(" distinct name ").limit(20).map(&:name).sort
    render :text => "<li>" + @names.map{|n| n } .join("</li><li>") + "</li>"
  end

  def start_call
    if request.post?
      session[:district] = params[:district]
      call_mode = params[:call_mode]
      if call_mode == "New"
        # record patient details
        redirect_to :controller => :patient,
                    :action => :search_by_name,
                    :action_type => 'new_client'  and return
      else
        # lookup caller (filtered by district)
        redirect_to "/start_call" and return
      end
      #raise params.inspect
    end
    render :layout => false
  end

  def house_cleaning
    render :layout => false
  end

  def admin
  	render :layout => false
  end

  def report
    render :layout => false
  end

  def list
    #----- Consider putting this in an array to get patients using the get_patient method from Patient Service library. ------------------
    @people = Patient.joins(:person => [:person_names, :person_addresses]).select('patient.*, person.*, person_name.*, person_address.*')
    #raise @people.inspect
    render :layout => false
  end 

  def health_facilities
    search_string = params[:search_string] || ''

    if !params[:tag].blank?
      location_tag    = LocationTag.find_by_name(params[:tag].gsub(/City/i, '').strip)
      names  = Location.where("m.location_tag_id = #{location_tag.id} AND name LIKE '%#{search_string}%' ").joins("INNER JOIN location_tag_map m
                          ON m.location_id = location.location_id").select(' distinct name ').limit(30).map(&:name).sort
    else
      location_tags   = LocationTag.where(" name IN ('Health Centre', 'District Hospital', 'Clinic',
     'Rural/Community Hospital', 'Dispensary', 'Central Hospital', 'Maternity', 'Other Hospital', 'Health Post')").collect{|l| l.id}
      names  = Location.where("m.location_tag_id IN (#{location_tags.join(', ')}) AND name LIKE '%#{search_string}%' ").joins("INNER JOIN location_tag_map m
                          ON m.location_id = location.location_id").select(' distinct name ').limit(30).map(&:name).sort
    end

    render :text => "<li>" + names.map{|n| n } .join("</li><li>") + "</li>"
  end

  def quick_summary
    @stats = Hash.new(0)
    @stats['Total clients registered'] = Patient.count
    @stats['Total clients registered (Women)'] = Patient.where("p.gender = 'F' OR p.gender = 'Female'").joins("INNER JOIN person p ON p.person_id=patient.patient_id").count
    @stats['Total clients registered (Men)'] = Patient.where("p.gender = 'M' OR p.gender = 'Male'").joins("INNER JOIN person p ON p.person_id=patient.patient_id").count

    render :layout => false
  end

  def view_tags
=begin
    tag_concepts = TagConceptRelationship.all
    @tag_concept_hash = {}
    
    tag_concepts.each do |tag_concept|
      tag_id = tag_concept.tag_id
      concept_id = tag_concept.concept_id
      tag_name = Publify.find(tag_id).name
      concept_name = ConceptName.where("concept_id = '#{concept_id}'").last.name
      @tag_concept_hash[concept_name] = {} if @tag_concept_hash[concept_name].blank?
      @tag_concept_hash[concept_name][tag_id] = tag_name
    end
=end
    @tags = Publify.all
  end

  def tag_concepts
    concept_names = []
    tag_concepts = TagConceptRelationship.where(tag_id: params[:tag_id])
    (tag_concepts || []).each  do |t|
      concept_names << [ConceptName.where(concept_id: t.concept_id).last.name, t.created_at.strftime('%d.%b.%Y %H:%M:%S')]
    end
      
    render text: concept_names.to_json and return
  end


  def view_tips
    render :layout => false
  end

  def create_tag_concept_relationships

    ActiveRecord::Base.transaction do
      concept_id = ConceptName.where("name = '#{params[:concept]}'").last.concept_id
      params[:tags].each do |tag|
        tag_id = Publify.where("name = '#{tag}'").last.id
        tag_concept_relationship = TagConceptRelationship.new
        tag_concept_relationship.concept_id = concept_id
        tag_concept_relationship.tag_id = tag_id
        tag_concept_relationship.save
      end
    end
    
    redirect_to("/configurations") and return
  end

  def retrieve_articles
      concept_id = ConceptName.where("name = '#{params[:concept]}'").last.concept_id
      tag_ids = TagConceptRelationship.where("concept_id = #{concept_id}").map(&:tag_id).join(",")
      tag_ids = '0' if tag_ids.blank?

      article_ids = Publify.find_by_sql("SELECT * FROM articles_tags  WHERE tag_id IN (#{tag_ids})"
          ).map(&:article_id).join(",")
      article_ids = '0' if article_ids.blank?
      articles = Publify.find_by_sql("SELECT * FROM contents WHERE id IN (#{article_ids})")
      
      articles_hash = {}
      article_override = nil
      article_key = nil
      articles.each do |article|
        article_id = article.id
        articles_hash[article_id]= {}
        articles_hash[article_id]["title"] = article.title.force_encoding("utf-8")
        if params[:title] && params[:title] ==  articles_hash[article_id]["title"]
          article_override = articles_hash[article_id]
          article_key = article_id
        end

        articles_hash[article_id]["author"] = article.author
        articles_hash[article_id]["body"] = article.body.force_encoding("utf-8")
      end

      titles = [];
      articles_hash.each do |key, article|
        titles << article['title']
      end

      session[:articles_hash] = articles_hash
      first_key = articles_hash.keys.first
      article = article_override.blank? ? articles_hash[first_key] : article_override
      hash = {:key => (article_key || first_key), :data => article, :all_keys => titles.join('|') }
      render :text => hash.to_json
  end

  def next_article
    key = !params[:key].blank? ? params[:key].to_i : -2
    next_item_pos = (session[:articles_hash].keys.index(key) + 1)
    disabled = false
    if (next_item_pos > (session[:articles_hash].keys.count - 2))
      disabled = true
    end
    if (next_item_pos > (session[:articles_hash].keys.count - 1))
      disabled = true
      next_item_pos = session[:articles_hash].keys.count - 1
    end

    titles = [];
    session[:articles_hash].each do |key, article|
      titles << article['title']
    end

    my_key = session[:articles_hash].keys[next_item_pos]
    article = session[:articles_hash][my_key]
    hash = {:key => my_key, :data => article, :disabled => disabled, :all_keys => titles.join('|')  }
    render :text => hash.to_json
  end

  def previous_article
    key = !params[:key].blank? ? params[:key].to_i : -2
    prev_item_pos = (session[:articles_hash].keys.index(key) - 1)
    disabled = false

    disabled = true if (prev_item_pos == 0)
    if prev_item_pos < 0
      prev_item_pos = 0
      disabled = true
    end

    titles = [];
    session[:articles_hash].each do |key, article|
      titles << article['title']
    end

    my_key = session[:articles_hash].keys[prev_item_pos]
    article = session[:articles_hash][my_key]
    hash = {:key => my_key, :data => article , :disabled => disabled, :all_keys => titles.join('|') }
    render :text => hash.to_json
  end
  
end
