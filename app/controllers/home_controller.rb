class HomeController < ApplicationController
  def index
    render :layout => false
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
    @names = ConceptName.where("name LIKE '%#{search_string}%'").joins("INNER JOIN concept_set s 
      ON concept_name.concept_id = s.concept_set").limit(10).map(&:name).sort
    render :text => "<li>" + @names.map{|n| n } .join("</li><li>") + "</li>"
  end

  def start_call
    if request.post?
      district = params[:district]
      call_mode = params[:call_mode]
      if call_mode == "New"
        # record patient details
        redirect_to :controller => :patient,
                    :action => :search_by_name,:action_type => 'new_client' and return
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

  def health_facilities
    search_string = params[:search_string] || ''
    @names = Location.where("name LIKE '%#{search_string}%'").limit(10).map(&:name).sort
    render :text => "<li>" + @names.map{|n| n } .join("</li><li>") + "</li>"
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
    render :layout => false
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
  
end
