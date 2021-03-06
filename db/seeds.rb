# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)
=begin
	#code to consider for DB Seed metadata1.7
unless Rails.env.production?
  connection = ActiveRecord::Base.connection
  connection.tables.each do |table|
    connection.execute("TRUNCATE #{table}") unless table == "schema_migrations"
  end
   
  # - IMPORTANT: SEED DATA ONLY
  # - DO NOT EXPORT TABLE STRUCTURES
  # - DO NOT EXPORT DATA FROM `schema_migrations`
  sql = File.read('db/openmrs_metadata_1_7.sql')
  statements = sql.split(/;$/)
  statements.pop  # the last empty statement
 
  ActiveRecord::Base.transaction do
    statements.each do |statement|
      connection.execute(statement)
    end
  end
end

# Seeding metadata_1_7 into Application Database
ActiveRecord::Schema.define(version: 0) do
	db_user = YAML::load_file('config/database.yml')[Rails.env]['username']
	db_password = YAML::load_file('config/database.yml')[Rails.env]['password']
	db_database = YAML::load_file('config/database.yml')[Rails.env]['database']

	system "mysql -u #{db_user} -p#{db_password} #{db_database} < db/openmrs_metadata_1_7.sql -v"
end
#end
=end

birthdate_entered = Date.today
person = Person.create(:birthdate => birthdate_entered, :birthdate_estimated => 1, :creator => 1)
person_name = PersonName.create(:given_name => "System", :family_name => "Admininistrator",:person_id => person.id)
PersonNameCode.create(:given_name_code => "System".soundex, :family_name_code => "Admininistrator".soundex,:person_name_id => person_name.id)

user = User.create(:username => 'admin',:password => "adminhotline", :creator => 1, :person_id => person.id,:system_id => "admin")

User.current = user


puts '<<<<<<<  Adding Relationships  >>>>>>>>>>'
[
	['Doctor', 'Patient', 'Relationship from a primary care provider to the patient'],
	['Sibling', 'Sibling', 'Relationship between brother/sister, brother/brother, and sister/sister'],
	['Parent', 'Child', 'Relationship from a mother/father to the child'],
	['Aunt/Uncle', 'Niece/Nephew', ''],
	['Patient', 'Guardian', 'Patient Guardian'],
	['Patient', 'Village Health Worker', 'Specifies village health worker for a particular patient.'],
	['Treatment Supporter', 'Treatment Suportee', 'Used by the mdrtb module.'],
	['TB Contact Person', 'TB Index Person', 'This is a relationship between a TB contact person and a current TB patient who referred them to clinic'],
	['Child', 'Parent', 'Relationship from child to parent'],
	['Spouse/Partner', 'Spouse/Partner', 'Spouse to spouse relationship'],
	['Other', 'Other', 'Other type of relationship to the person']].each do |a_is_to_b, b_is_to_a, desc|
	relationship_type =  RelationshipType.where(:a_is_to_b => a_is_to_b, :b_is_to_a => b_is_to_a).first
	if relationship_type.blank?
		RelationshipType.create(
			:a_is_to_b => a_is_to_b,
			:b_is_to_a => b_is_to_a,
			:creator => user.id
		)
	end
end

puts "Creating user roles ...."
["Administrator","Provider"].each do |role|
  Role.create(description: 'User roles', role: role)
end

puts "Assigning #{user.username} roles ...."
["System Developer","Provider"].each do |role|
  UserRole.create(:user_id => user.id, :role => role)
end


###################################### Creating locations ################################################################
districts = {}
location_tags = []

=begin
CSV.foreach("#{Rails.root}/app/assets/data/health_facilities.csv", :headers => true) do |row|
  district_name = row[0] ; facility_name = row[3]
  facility_code = row[2] ; district_code = row[1]
  region = row[4].split(' ')[0] rescue nil
  facility_type = row[5] ; description = row[6] 
  facility_location = row[7] ; latitude = row[8] ; longitude = row[9]
  
  
  next if district_name.blank?  
  district_name = "Nkhata-bay" if district_name.match(/nkhata/i) 
  location_tags << row[5]
  districts[district_name] = [] if districts[district_name].blank?
  districts[district_name] << [
                                district_code,facility_code, 
                                facility_name,region,facility_type,
                                description,facility_location,
                                latitude, longitude  
                              ] 
end

puts "Creating districts, facilities and location_tag_map ...."
location_tags = location_tags.uniq + ["Region","District","Traditional Authority","Village","Urban","Rural","Facility location"] + districts.keys

location_tags.each do |location|
  description = nil
  description = 'Malawian district' if location == 'District'
  description = 'One of the three regions of Malawi' if location == 'Region'
  description = 'Traditional Authority' if location == 'Traditional Authority'
  description = 'Village' if location == 'Village'
  LocationTag.create(:name => location, :description => description)
end

(districts || {}).each do |district, facilities|
  location = Location.create(:name => district, :description => "Malawian district")
  LocationTagMap.create(location_id: location.id, location_tag_id: LocationTag.where(:name => 'District').first.id)
  region = nil ; district_code = nil

  (facilities || []).each do |facility_attr| 
    facility = Location.create(:name => facility_attr[2],postal_code: facility_attr[1], 
      :description => facility_attr[5],parent_location: location.id,
      latitude: facility_attr[7], longitude: facility_attr[8])

    #Tagging facilit to a facility tag (Clinic/Hospitl/Health center/Central Hosp)
    LocationTagMap.create(location_id: facility.id, location_tag_id: LocationTag.find_by_name(facility_attr[4]).id)
    #Tagging facilit to a facility tag (Urban/Rural)
    LocationTagMap.create(location_id: facility.id, location_tag_id: LocationTag.find_by_name(facility_attr[6]).id)
    #Tagging a facility to district
    LocationTagMap.create(location_id: facility.id, location_tag_id: LocationTag.find_by_name(district).id)

    region = facility_attr[3] if region.blank?
    district_code = facility_attr[0] if district_code
    puts "#{district} >>>>>>>>>>>>>>>>>>>>>>>>> #{facility_attr[2]}"
  end
  #Updating the created district to now have a district_code and a district region
  region_id = LocationTag.find_by_name(region).id rescue LocationTag.create(name: region, description: 'Regions of Malawi')
  location.update_attributes(region: region_id,postal_code: district_code)
end


districts_with_ta_and_villages = {}
district_ta_and_villages_json = JSON.parse(`cat #{Rails.root}/app/assets/data/districts.json`)

(district_ta_and_villages_json || {}).each do |raw_district_name, ta_and_thier_villages|
  if raw_district_name.match(/-/)
    district_name = raw_district_name.strip.capitalize
  else
    district_name = raw_district_name.strip
  end
  puts "setting up TAs and villages for .......... #{district_name}"

  district = Location.where("t.name = 'District' AND location.name = ?",
             district_name).joins("INNER JOIN location_tag_map m ON m.location_id = location.location_id
             INNER JOIN location_tag t ON t.location_tag_id = m.location_tag_id").first rescue nil
             

  if district.blank?
    new_district = Location.create(name: district_name, description: "A sub district")
    tag_map_id = LocationTag.find_by_name('District').id
    LocationTagMap.create(location_id: new_district.id, location_tag_id: tag_map_id)
    parent_district = Location.find_by_name('Lilongwe') if district_name.match(/Lilongwe/i)
    parent_district = Location.find_by_name('Blantyre') if district_name.match(/Blantyre/i)
    parent_district = Location.find_by_name('Mzimba') if district_name.match(/Mzuzu/i)
    parent_district = Location.find_by_name('Zomba') if district_name.match(/Zomba/i)
    new_district.update_attributes(parent_location: parent_district.id)
    district = new_district
  end

  districts_with_ta_and_villages[district.name] = {} if districts_with_ta_and_villages[district.name].blank?
  (district_ta_and_villages_json[district.name].keys || []).each do |ta_name|
    districts_with_ta_and_villages[district.name][ta_name] = [] if districts_with_ta_and_villages[district.name][ta_name].blank?
    (district_ta_and_villages_json[district.name][ta_name] || []).each do |village_name|
      districts_with_ta_and_villages[district.name][ta_name] << village_name
    end
  end
end

ta_location_tag = LocationTag.find_by_name('Traditional Authority')
village_location_tag = LocationTag.find_by_name('Village')
(districts_with_ta_and_villages || {}).each_with_index do |(district_name, ta_and_villages), i|
  district = Location.find_by_name(district_name)
  (ta_and_villages || {}).each do |ta, villages|
    traditional_authority = Location.create(name: ta, description: 'Traditional Authority')
    LocationTagMap.create(location_id: traditional_authority.id, location_tag_id: ta_location_tag.id)
    traditional_authority.update_attributes(parent_location: district.id)

    (villages || []).each_with_index do |village_name, i|
      village = Location.create(name: village_name, description: 'A village under a TA')
      LocationTagMap.create(location_id: village.id, location_tag_id: village_location_tag.id)
      village.update_attributes(parent_location: traditional_authority.id)
      puts "#{traditional_authority.name} >>>>  #{village_name}"
    end
  end
end

location_tag = LocationTag.find_by_name('Facility location')
['Help desk','Call booth'].each do |name|
  location = Location.create(name: name, description: 'Facility location')
  LocationTagMap.create(location_id: location.id, location_tag_id: location_tag.id)
end
###################################### Creating locations ends ################################################################

=end

Rails.env = 'development' if Rails.env.blank?

db_user = YAML::load_file('config/database.yml')[Rails.env]['username']
db_password = YAML::load_file('config/database.yml')[Rails.env]['password']
db_database = YAML::load_file('config/database.yml')[Rails.env]['database']

r = `mysql -u #{db_user} -p#{db_password} #{db_database} < db/locations.sql -v`

###################################### Creating Global properties ##############################################################
global_properties = [
  ['call.modes','New,Repeat'],
  ['current.health.center',1040]
]

(global_properties || []).each do |description, property_value|
  GlobalProperty.create(property_value: property_value, description: description)
end
###################################### Creating Global properties ends ##############################################################


###################################### Creating Patient Identifiers ends ##############################################################
patient_identifier_types = [['IVR access code','Used in mnch hotline to identify individual callers'],
  ['HTC identifier','Number used for identifying HTC clients'],
  ['ANC Connect ID','ANC Connect Unique Identifier'],
  ['HCC Number','HIV Care Clinic for Pre-ART patients and Exposed Children'],
  ['National id','National ID number developed by Baobab'],
  ['Unknown ID','Unknown ID as scanned by the system']
]

(patient_identifier_types || []).each do |name,desc|
  PatientIdentifierType.create(name: name,description: desc)
end
###################################### Creating Patient Identifiers ends ##############################################################


###################################### Creating Person attributes starts ##############################################################
attributes = [['Cell phone number','Person primary cell phone number'],
  ['Office phone number','Person office phone number. Usually fixed line phone number'],
  ['Home phone number','Person home phone number, usually fixed line phone number'],
  ['Ancestral Traditional Authority','T/A'],
  ['Current Place Of Residence','Place of stay'],
  ['Occupation','This is the current patient occupation'],
  ['Home Village',"The person's home village or place of origin"],
  ['Citizenship','Country of which this person is a member'],
  ['Education','Maternity required this field'],
  ['Religion','Maternity required this field'],
  ['Civil Status','Marriage status of this person'],
  ['Race','Group of persons related by common descent or heredity'],
  ['Health surveillance assistant','HSA: Health Surveillance Assistants provide a life-saving link between communities and the health care system'],
  ['Nearest Health Facility', 'Closet facility to seek health care services']
]

(attributes || []).each do |name,desc|
  PersonAttributeType.create(name: name,description: desc)
end
###################################### Creating Person attributes ends ##############################################################


###################################### Creating Concepts starts ##############################################################
diagnosis_concept_datatype = ConceptDataType.create(:name => 'Coded', :hl7_abbreviation => 'CWE',
  :description => "Value determined by term dictionary lookup (i.e., term identifier)")
diagnosis_concept_class = ConceptClass.create(:name => 'Diagnosis', :description => "Conclusion drawn through findings")

concept_diagnosis = Concept.create(:datatype_id => diagnosis_concept_datatype.concept_datatype_id,
  :class_id => diagnosis_concept_class.concept_class_id)
diagnosis_set = ConceptName.create(:name => 'Danger sign',:concept_id => concept_diagnosis.concept_id, :locale => 'en')



health_information_concept_class = ConceptClass.create(:name => 'Question', :description => "Question (eg, patient history, SF36 items)")
health_information_concept_datatype = ConceptDataType.find_by_name('Coded')
concept_health_information = Concept.create(:datatype_id => health_information_concept_datatype.concept_datatype_id,
  :class_id => health_information_concept_class.concept_class_id)
health_information_set = ConceptName.create(:name => 'Health information',:concept_id => concept_health_information.concept_id, :locale => 'en')


health_symptom_concept_class = ConceptClass.find_by_name('Question')
health_symptom_concept_datatype = ConceptDataType.find_by_name('Coded')
concept_symptom = Concept.create(:datatype_id => health_symptom_concept_datatype.concept_datatype_id,
  :class_id => health_symptom_concept_class.concept_class_id)
health_information_set = ConceptName.create(:name => 'Health symptom',:concept_id => concept_symptom.concept_id, :locale => 'en')


anc_visit_concept_class = ConceptClass.find_by_name('Question')
anc_visit_concept_datatype = ConceptDataType.find_by_name('Coded')
concept_anc_visit = Concept.create(:datatype_id => anc_visit_concept_datatype.concept_datatype_id,
  :class_id => anc_visit_concept_class.concept_class_id)
anc_visit_set = ConceptName.create(:name => 'Reason for not visiting ANC client',:concept_id => concept_anc_visit.concept_id, :locale => 'en')


concept_name = nil ; set = nil ; concept_class = nil ; concept_datatype = nil
CSV.foreach("#{Rails.root}/app/assets/data/concept_sets_details.csv", :headers => true).with_index do |row, i|
  concept_name = row[0].strip rescue nil
  next if concept_name.blank?

  if concept_name == 'group concept = "Danger sign"'
    concept_class = ConceptClass.find_by_name('Diagnosis')
    concept_datatype = ConceptDataType.find_by_name('Coded')
    set = ConceptName.find_by_name('Danger sign')
    next
  elsif concept_name == 'group concept = "Health information"'
    concept_class = ConceptClass.find_by_name('Question')
    concept_datatype = ConceptDataType.find_by_name('Coded')
    set = ConceptName.find_by_name('Health information')
    next
  elsif concept_name == 'group concept = "Health symptom"'
    concept_class = ConceptClass.find_by_name('Question')
    concept_datatype = ConceptDataType.find_by_name('Coded')
    set = ConceptName.find_by_name('Health symptom')
    next
  elsif concept_name == 'group concept = "Reason for not visiting ANC client"'
    concept_class = ConceptClass.find_by_name('Question')
    concept_datatype = ConceptDataType.find_by_name('Coded')
    set = ConceptName.find_by_name('Reason for not visiting ANC client')
    next
  end
 
  concept = Concept.create(datatype_id: concept_datatype.concept_datatype_id, class_id: concept_class.concept_class_id)
  ConceptName.create(name: concept_name, concept_id: concept.concept_id, locale: 'en')
  ConceptSet.create(concept_id: set.concept_id, concept_set: concept.concept_id)
  puts "Created concept: #{concept_name} ...."
end
###################################### Creating Concepts ends ##############################################################



###################################### Creating Additional Concepts starts ##############################################################
  concept_class = ConceptClass.find_by_name('Question')
  concept_datatype = ConceptDataType.create(:name => 'N/A', :hl7_abbreviation => 'ZZ',
  :description => "Not associated with a datatype (e.g., term answers, sets)")


  CSV.foreach("#{Rails.root}/app/assets/data/additional_concept_names.csv", :headers => true).with_index do |row, i|
    concept_name = row[0].strip
    check = ConceptName.where(:name => concept_name).last
    next if !check.blank?
    concept = Concept.create(datatype_id: concept_datatype.concept_datatype_id, class_id: concept_class.concept_class_id)
    ConceptName.create(name: concept_name, concept_id: concept.concept_id, locale: 'en')
    puts "Additional concept: ---- #{concept_name}"
  end

###################################### Creating Additional Concepts ends ##############################################################



###################################### Creating Concepts sets ##############################################################
select_options = {
  'maternal_health_info' => [
      ['Anemia','ANEMIA'],
      ['Antenatal care','ANTENATAL CARE'],
      ['Body changes', 'BODY CHANGES'],
      ['Beliefs', 'BELIEFS'],
      ['Baby\'s growth', 'BABY\'S GROWTH'],
      ['Birth planning - male','BIRTH PLANNING MALE'],
      ['Birth planning - female','BIRTH PLANNING FEMALE'],
      ['Cervical cancer','CERVICAL CANCER'],
      ['Concerns', 'CONCERNS'],
      ['Discomfort', 'DISCOMFORT'],
      ['Emotions', 'EMOTIONS'],
      ['Family planning','FAMILY PLANNING'],
      ['Healthcare visits', 'HEALTHCARE VISITS'],
      ['Malaria','MALARIA'],
      ['Milestones', 'MILESTONES'],
      ['Nutrition', 'NUTRITION'],
      ['Prevention', 'PREVENTION'],
      ['Routines', 'ROUTINES'],
      ['Warning signs', 'WARNING SIGNS'],
      ['Other','OTHER']
  ],
  'maternal_health_symptoms' => [
      ['Abdominal pain','ABDOMINAL PAIN'],
      ['Fever during pregnancy','FEVER DURING PREGNANCY SYMPTOM'],
      ['Fits or convulsions','FITS OR CONVULSIONS SYMPTOM'],
      ['Frequent miscarriages','FREQUENT MISCARRIAGES'],
      ['Headaches','HEADACHES'],
      ['Infertility','INFERTILITY'],
      ['No fetal movements','NO FETAL MOVEMENTS SYMPTOM'],
      ['Paleness of the skin and tiredness','PALENESS OF THE SKIN AND TIREDNESS SYMPTOM'],
      ['Postnatal bleeding','POSTNATAL BLEEDING'],
      ['Postnatal discharge - bad smell','POSTNATAL DISCHARGE BAD SMELL'],
      ['Postnatal fever','POSTNATAL FEVER SYMPTOM'],
      ['Problems with family planning method','PROBLEMS WITH FAMILY PLANNING METHOD'],
      ['Problems with monthly periods','PROBLEMS WITH MONTHLY PERIODS'],
      ['Swollen hands or feet','SWOLLEN HANDS OR FEET SYMPTOM'],
      ['Water breaks','WATER BREAKS SYMPTOM'],
      ['Vaginal Bleeding during pregnancy','VAGINAL BLEEDING DURING PREGNANCY'],
      ['Vaginal bleeding (not during pregnancy)','VAGINAL BLEEDING NOT DURING PREGNANCY'],
      ['Vaginal itching','VAGINAL ITCHING'],
      ['Vaginal discharge ','VAGINAL DISCHARGE'],
      ['None','NONE'],
      ['Other','OTHER']
  ],
  'child_health_symptoms' => [
      ['Convulsions','CONVULSIONS'],
      ['Coughing','COUGHING'],
      ['Diarrhea','DIARRHEA'],
      ['Fever','FEVER'],
      ['Red eye','RED EYE'],
      ['Skin conditions','SKIN CONDITIONS'],
      ['Sleepy/unconscious','SLEEPY/UNCONSCIOUS'],
      ['Swollen legs or face','SWOLLEN LEGS OR FACE'],
      ['Trouble eating/drinking','TROUBLE EATING/DRINKING'],
      ['Weight loss/gain','WEIGHT LOSS/GAIN']
  ],
  #TODO - add the new symptoms above, danger signs below on to concept server
  'danger_signs' => [
      ['Excessive postnatal bleeding','EXCESSIVE POSTNATAL BLEEDING'],
      ['Fever during pregnancy','FEVER DURING PREGNANCY SIGN'],
      ['Fits or convulsions','FITS OR CONVULSIONS SIGN'],
      ['Heavy vaginal bleeding during pregnancy','HEAVY VAGINAL BLEEDING DURING PREGNANCY'],
      ['No fetal movements','NO FETAL MOVEMENTS SIGN'],
      ['Paleness of the skin and tiredness','PALENESS OF THE SKIN AND TIREDNESS SIGN'],
      ['Postnatal fever','POSTNATAL FEVER SIGN'],
      ['Severe abdominal pain','ACUTE ABDOMINAL PAIN'],
      ['Severe headache','SEVERE HEADACHE'],
      ['Swollen hands, feet, and face','SWOLLEN HANDS OR FEET SIGN'],
      ['Water breaks','WATER BREAKS SIGN']    
  ],
  'child_health_info' => [
      ['Accessing healthcare services','ACCESSING HEALTHCARE SERVICES'],
      ['Bowel movements','BOWEL MOVEMENTS'],
      ['Bulging fontanel' , 'Bulging fontanel'],
      ['Chest in-drawing', 'Chest in-drawing'],
      ['crying','CRYING'],
      ['Eye infection', 'Eye infection'],
      ['Fast breathing', 'Fast breathing'],
      ['Feeding problems','FEEDING PROBLEMS'],
      ['Growth milestones','GROWTH MILESTONES'],
      ['Jaundice', 'Jaundice'],
      ['Skin rashes','SKIN RASHES'],
      ['Skin infections','SKIN INFECTIONS'],
      ['Sleeping','SLEEPING'],
      ['Umbilicus infection','UMBILICUS INFECTION'],
      ['Other','OTHER']
  ],
  'type_of_message_content' => [
      ['Child', 'Child'],
      ['Observer', 'Observer'],
      ['Pregnancy', 'Pregnancy'],
      ['Postnatal', 'Postnatal'],
      ['WCBA', 'WCBA']
  ],
  'message_type' => [
      ['SMS', 'SMS'],
      ['Voice','VOICE']
  ],
  'phone_type' => [
      ['Community phone', 'COMMUNITY PHONE'],
      ['Family member phone', 'FAMILY MEMBER PHONE'],
      ['Neighbour\'s phone', 'NEIGHBOUR\'S PHONE'], #TODO check if this will work
      ['Personal phone', 'PERSONAL PHONE']
  ],
  'language_type' => [
      ['Chichewa', 'CHICHEWA'],
      ['Chiyao', 'CHIYAO']
  ],
  'pregnancy_status' => [
      ['Pregnant', 'Pregnant'],
      ['NOT pregnant', 'NOT pregnant'],
      ['Delivered', 'Delivered'],
      ['Miscarried', 'Miscarried']
  ],
  'child_danger_signs_greater_zero_outcome' => [
      ['Given advice', 'GIVEN ADVICE'],
      ['Referral to Hospital', 'REFERRAL TO HOSPITAL'],
      ['Referral to emergency transport','REFERRAL TO EMERGENCY TRANSPORT' ],
      ['Referred to a health centre', 'REFERRED TO A HEALTH CENTRE'],
      ['Referred to nearest village clinic', 'REFERRED TO NEAREST VILLAGE CLINIC'],
      ['Registered for Tips and reminders','REGISTERED FOR TIPS AND REMINDERS' ], #'REGISTERED FOR TIPS AND REMINDERS']
      ['Other','OTHER' ] #'REGISTERED FOR TIPS AND REMINDERS']
  ],
  'child_symptoms_greater_zero_outcome' => [
      ['Given advice', 'GIVEN ADVICE'],
      ['Referral to Hospital', 'REFERRAL TO HOSPITAL'],
      ['Referral to emergency transport','REFERRAL TO EMERGENCY TRANSPORT' ],
      ['Referred to a health centre', 'REFERRED TO A HEALTH CENTRE'],
      ['Referred to nearest village clinic', 'REFERRED TO NEAREST VILLAGE CLINIC'],
      ['Registered for Tips and reminders','REGISTERED FOR TIPS AND REMINDERS' ], #'REGISTERED FOR TIPS AND REMINDERS']
      ['Other','OTHER' ] #'REGISTERED FOR TIPS AND REMINDERS']
  ],
  'general_outcome' => [
      ['Given advice', 'GIVEN ADVICE'],
      ['Referral to Hospital', 'REFERRAL TO HOSPITAL'],
      ['Registration','REGISTRRATION' ], #'REGISTERED FOR TIPS AND REMINDERS'],
      ['Referral to CCPF doctor -  answered', 'REFERRAL TO CCPF DOCTOR - ANSWERED'],
      ['Referral to CCPF doctor - unanswered', 'REFERRAL TO CCPF DOCTOR - UNANSWERED'],
      ['Referral to emergency transport','REFERRAL TO EMERGENCY TRANSPORT'],
      ['Referral to health centre', 'REFERRAL TO HEALTH CENTRE'],
      ['Referral for nutritional assessment', 'REFERRAL FOR NUTRITIONAL ASSESSMENT'],
      ['Referral to nurse consultant', 'REFERRAL TO NURSE CONSULTANT'],
      ['Referral to village clinic', 'REFERRAL TO VILLAGE CLINIC'],
      ['Other','OTHER' ]
  ],
  'referral_reasons' => [
      ['Danger signs observed', 'DANGER SIGNS OBSERVED'],
      ['Follow-up on previous treatment', 'FOLLOW-UP ON PREVIOUS TREATMENT'],
      ['No health center or Hospital referral', 'NO HEALTH CENTER OR HOSPITAL REFERRAL'],
      ['Physical exam needed', 'PHYSICAL EXAM NEEDED'],
      ['Village clinic not accessible', 'VILLAGE CLINIC NOT ACCESSIBLE'],
      ['Other', 'OTHER']
  ],

  'reason_for_not_attending_anc' => [
      ['Clinic too far','Clinic too far'],
      ['No time to go','No time to go'],
      ['Poor care at clinic','Poor care at clinic'],
      ['Too early in pregnancy','Too early in pregnancy'],
      ['Did not know I should go','Did not know I should go'],
      ['HSA unable to visit client','HSA unable to visit client'],
      ['HSA cannot find client','HSA cannot find client'],
      ['Client died','Client died'],
      ['Client miscarried','Client miscarried'],
      ['Client delivered','Client delivered'],
      ['Client moved','Client moved'],
      ['Other','Other']
  ],

  'reason_for_not_visiting_anc_client' => [
      ['HSA too busy','HSA too busy'],
      ['HSA Cannot find client','HSA Cannot find client'],
      ['Client moved','Client moved'],
      ['Client miscarried','Client miscarried'],
      ['Client delivered','Client delivered'],
      ['Client died','Client died'],
      ['Other','Other']
  ],

  'general_health_symptoms' => [
      ["Weakness- General", ''],
      ["Swelling- General", ''],
      ["Stool/urine conditions", ''],
      ["Stomach pain / Cyst, Lumps, Mass", ''],
      ["Skin condition- Genital", ''],
      ["Respiratory conditions", ''],
      ["Puberty / Menstrual conditions", ''],
      ["Physical injury, Swelling- General", ''],
      ["None- General Health Concerns", ''],
      ["Muscle pain", ''],
      ["Menstrual conditions", ''],
      ["Joint pain", ''],
      ["Headache", ''],
      ["Gastrointestinal distress", ''],
      ["Fever", ''],
      ["Eye (vision issues/pain)", ''],
      ["Dizziness", ''],
      ["Discharge- Genital (Vaginal or Penile)", ''],
      ["Dental/oral conditions, Mouth, Throat", ''],
      ["Cyst, Lumps, Mass", ''],
      ["Convulsions", ''],
      ["Chest pain", ''],
      ["Bleeding", ''],
      ["Behavioral changes/ Mental health", ''],
      ["Appetite changes (loss/gain)", ''],
      ["Weight change (loss/gain)", '']
  ]
}

(select_options || {}).each do |concept_name, concept_sets|
  concept_name = concept_name.gsub('_',' ').strip
  concept_names = ConceptName.where(name: concept_name).first 
  if concept_names.blank?
    concept = Concept.create(datatype_id: concept_datatype.concept_datatype_id, class_id: concept_class.concept_class_id)
    ConceptName.create(name: concept_name, concept_id: concept.concept_id, locale: 'en')
  else
    concept = concept_names.concept
  end
  
  (concept_sets || []).each do |set_name,set_desc|
    concept_set_name = set_name 
    concept_set = ConceptName.where(name: concept_set_name).first 
    if concept_set.blank?
      concept_set = Concept.create(datatype_id: concept_datatype.concept_datatype_id, class_id: concept_class.concept_class_id)
      ConceptName.create(name: concept_set_name, concept_id: concept_set.concept_id, locale: 'en')
    end
    ConceptSet.create(concept_id: concept.concept_id, concept_set: concept_set.concept_id)
    puts "Created concept set: #{concept_name} .... #{concept_set_name}"
  end
end
###################################### Creating Concepts sets ends ##############################################################



###################################### Encounter Type starts ##############################################################
  CSV.foreach("#{Rails.root}/app/assets/data/encouters_with_descrptions.csv", :headers => true).with_index do |row, i|
    name = row[0].strip ; des = row[1].capitalize
    EncounterType.create(name: name, description: des)
    puts "EncounterType ---- #{name}"
  end
###################################### Encounter Type end ##############################################################


  puts "Your new user is: admin, password: adminhotline"
