
class Encounter < ActiveRecord::Base
  self.table_name = "encounter"
  include Openmrs
  default_scope { where(voided: 0) }

	belongs_to :patient 
	has_many :observations
  belongs_to :type, class_name: "EncounterType", foreign_key: "encounter_type"

  def self.last_data(name, patient_id)
    encounter_type_id  = EncounterType.find_by_name(name).id
    data = {}

    (Encounter.find_by_sql(["SELECT * FROM encounter WHERE encounter_type = #{encounter_type_id}
                     AND DATE(encounter_datetime) < ? AND patient_id = #{patient_id}
                     ", Date.today])
    .last.observations rescue []).each do |observation|
      data[observation.concept_name.name.upcase.strip] = [] if data[observation.concept_name.name.upcase.strip].blank?
      data[observation.concept_name.name.upcase.strip] << observation.answer_string
    end

    data
  end

  def self.current_data(name, patient_id)
    encounter_type_id  = EncounterType.find_by_name(name).id
    data = {}

    (Encounter.find_by_sql(["SELECT * FROM encounter WHERE encounter_type = #{encounter_type_id}
                     AND DATE(encounter_datetime) = ? AND patient_id = #{patient_id}
                            ", Date.today])
    .last.observations rescue []).each do |observation|
      data[observation.concept_name.name.upcase.strip] = [] if data[observation.concept_name.name.upcase.strip].blank?
      data[observation.concept_name.name.upcase.strip] << observation.answer_string
    end

    data
  end

  def self.current_food_groups(name, patient_id)
    encounter_type_id  = EncounterType.find_by_name(name).id
    concept_id = ConceptName.find_by_name("Food Type").concept_id
    data = []

    (Encounter.find_by_sql(["SELECT * FROM encounter WHERE encounter_type = #{encounter_type_id}
                     AND DATE(encounter_datetime) = ? AND patient_id = #{patient_id}
                     ", Date.today])
    .last.observations rescue []).each do |observation|
      next if observation.concept_id.to_s != concept_id.to_s
      data << observation.answer_string
    end

    data
  end

  def self.feed_tags(patient_id)
    max_tag = Observation.find_by_sql("SELECT MAX(comments) AS max_tag FROM obs WHERE person_id = #{patient_id} LIMIT 1")[0]['max_tag'].to_i rescue 0
    tag = max_tag + 1

    ActiveRecord::Base.connection.execute(<<-EOQ)
  UPDATE obs
  SET obs.comments = #{tag}
  WHERE obs.person_id = #{patient_id} AND (obs.comments IS NULL OR obs.comments = '')
  AND DATE(obs.obs_datetime) ='#{Date.today.to_s(:db)}'
    EOQ
  end

  def self.current_encounters(patient_id)
    self.find_by_sql("
      SELECT encounter.* FROM encounter
      INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
      INNER JOIN (
          SELECT e.encounter_id, e.encounter_type, MAX(e.encounter_id) AS max_enc FROM encounter e
              INNER JOIN obs o ON o.encounter_id = e.encounter_id
              WHERE e.patient_id = #{patient_id}
                AND e.encounter_datetime BETWEEN '#{Date.today.strftime('%Y-%m-%d 00:00:00')}'
                AND '#{Date.today.strftime('%Y-%m-%d 23:59:59')}' AND COALESCE(o.comments, '') = ''
              GROUP BY e.encounter_type
        ) AS der_e ON encounter.encounter_id = der_e.max_enc AND encounter.encounter_type = der_e.encounter_type

      WHERE encounter.voided = 0 AND encounter.patient_id = #{patient_id}
        AND encounter.encounter_datetime BETWEEN '#{Date.today.strftime('%Y-%m-%d 00:00:00')}'
        AND '#{Date.today.strftime('%Y-%m-%d 23:59:59')}' AND COALESCE(obs.comments, '') = ''
      GROUP BY encounter.encounter_type
      ORDER BY encounter.encounter_datetime DESC
    ")
  end

  def self.previous_encounters(patient_id)
    Encounter.find_by_sql("
      SELECT encounter.* FROM encounter
      INNER JOIN obs ON obs.encounter_id = encounter.encounter_id

      INNER JOIN (
          SELECT e.encounter_id, e.encounter_type, MAX(e.encounter_id) AS max_enc FROM encounter e
              INNER JOIN obs o ON o.encounter_id = e.encounter_id
              WHERE e.patient_id = #{patient_id}
                AND e.encounter_datetime <= '#{Date.today.strftime('%Y-%m-%d 23:59:59')}' AND COALESCE(o.comments, '') != ''
              GROUP BY o.comments, e.encounter_type
        ) AS der_e ON encounter.encounter_id = der_e.max_enc AND encounter.encounter_type = der_e.encounter_type

      WHERE encounter.voided = 0 AND encounter.patient_id = #{patient_id}
        AND encounter.encounter_datetime <= '#{Date.today.strftime('%Y-%m-%d 23:59:59')}' AND COALESCE(obs.comments, '') != ''
      GROUP BY obs.comments, encounter.encounter_type
      ORDER BY encounter.encounter_datetime DESC
    ")
  end

  def self.all_encounters_by_type(patient_id, types=[])
    types_join1 = types.blank? ? "" : " e.encounter_type IN (#{types.join(', ')})"
    types_join2 = types.blank? ? "" : " encounter.encounter_type IN (#{types.join(', ')})"

    Encounter.find_by_sql("
      SELECT encounter.* FROM encounter
      INNER JOIN obs ON obs.encounter_id = encounter.encounter_id

      INNER JOIN (
          SELECT e.encounter_id, e.encounter_type, MAX(e.encounter_id) AS max_enc FROM encounter e
              INNER JOIN obs o ON o.encounter_id = e.encounter_id
              WHERE e.patient_id = #{patient_id} AND #{types_join1}
                AND e.encounter_datetime <= '#{Date.today.strftime('%Y-%m-%d 23:59:59')}'
              GROUP BY o.comments, e.encounter_type
        ) AS der_e ON encounter.encounter_id = der_e.max_enc AND encounter.encounter_type = der_e.encounter_type

      WHERE encounter.patient_id = #{patient_id} AND #{types_join2}
        AND encounter.encounter_datetime <= '#{Date.today.strftime('%Y-%m-%d 23:59:59')}'
      GROUP BY obs.comments, encounter.encounter_type
      ORDER BY encounter.encounter_datetime DESC
    ")
  end

end
