-- clinic_db.sql
-- Clinic Booking System
-- Drop existing objects (safe to run)
DROP DATABASE IF EXISTS clinic_db;
CREATE DATABASE clinic_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE clinic_db;

-- ----------------------------------------------------------------
-- Table: users (system users / staff)
-- ----------------------------------------------------------------
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(200) NOT NULL,
    role ENUM('admin','receptionist','doctor','nurse','pharmacist','accountant') NOT NULL DEFAULT 'receptionist',
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: patients
-- ----------------------------------------------------------------
CREATE TABLE patients (
    patient_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    national_id VARCHAR(50) UNIQUE, -- e.g., ID/passport
    date_of_birth DATE,
    gender ENUM('male','female','other') DEFAULT 'other',
    phone VARCHAR(30),
    email VARCHAR(255),
    address TEXT,
    emergency_contact_name VARCHAR(200),
    emergency_contact_phone VARCHAR(30),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (char_length(first_name) > 0)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: specialties (for doctors)
-- ----------------------------------------------------------------
CREATE TABLE specialties (
    specialty_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: doctors
-- ----------------------------------------------------------------
CREATE TABLE doctors (
    doctor_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL UNIQUE, -- optional link to users table (One-to-One)
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(30),
    email VARCHAR(255),
    license_number VARCHAR(100) NOT NULL UNIQUE,
    hire_date DATE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Many-to-Many: doctor_specialties (doctors <-> specialties)
-- ----------------------------------------------------------------
CREATE TABLE doctor_specialties (
    doctor_id INT NOT NULL,
    specialty_id INT NOT NULL,
    PRIMARY KEY (doctor_id, specialty_id),
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    FOREIGN KEY (specialty_id) REFERENCES specialties(specialty_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Many-to-Many: patient_doctors (patients have many doctors and vice versa)
-- ----------------------------------------------------------------
CREATE TABLE patient_doctors (
    patient_id INT NOT NULL,
    doctor_id INT NOT NULL,
    is_primary TINYINT(1) NOT NULL DEFAULT 0,
    assigned_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    PRIMARY KEY (patient_id, doctor_id),
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: rooms (for appointments that use rooms)
-- ----------------------------------------------------------------
CREATE TABLE rooms (
    room_id INT AUTO_INCREMENT PRIMARY KEY,
    room_name VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(255),
    capacity INT NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: services (consultation types, lab tests, procedures)
-- ----------------------------------------------------------------
CREATE TABLE services (
    service_id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    price DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    duration_minutes INT NOT NULL DEFAULT 30,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: appointments
-- One-to-Many: patient -> appointments
-- One-to-Many: doctor -> appointments
-- Optional One-to-One linking a room for that appointment slot (room_id may be NULL)
-- ----------------------------------------------------------------
CREATE TABLE appointments (
    appointment_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    doctor_id INT NOT NULL,
    room_id INT,
    scheduled_start DATETIME NOT NULL,
    scheduled_end DATETIME NOT NULL,
    status ENUM('scheduled','checked_in','in_progress','completed','cancelled','no_show') NOT NULL DEFAULT 'scheduled',
    reason TEXT,
    created_by INT, -- user who created the appointment (receptionist)
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_times CHECK (scheduled_end > scheduled_start),
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE RESTRICT,
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE RESTRICT,
    FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE SET NULL,
    FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Many-to-Many: appointment_services (appointments <-> services)
-- ----------------------------------------------------------------
CREATE TABLE appointment_services (
    appointment_id INT NOT NULL,
    service_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    unit_price DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (appointment_id, service_id),
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services(service_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: medications
-- ----------------------------------------------------------------
CREATE TABLE medications (
    medication_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    manufacturer VARCHAR(200),
    unit VARCHAR(50), -- e.g., tablet, ml
    strength VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(name, strength)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: prescriptions (one per appointment optionally)
-- One-to-One: appointment <-> prescription (enforced by unique appointment_id)
-- ----------------------------------------------------------------
CREATE TABLE prescriptions (
    prescription_id INT AUTO_INCREMENT PRIMARY KEY,
    appointment_id INT NOT NULL UNIQUE,
    prescribed_by INT NOT NULL, -- doctor user_id OR doctor_id reference through doctors table
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id) ON DELETE CASCADE,
    FOREIGN KEY (prescribed_by) REFERENCES doctors(doctor_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: prescription_items (prescription -> medications) (one-to-many)
-- ----------------------------------------------------------------
CREATE TABLE prescription_items (
    prescription_item_id INT AUTO_INCREMENT PRIMARY KEY,
    prescription_id INT NOT NULL,
    medication_id INT NOT NULL,
    dosage VARCHAR(100) NOT NULL,
    frequency VARCHAR(100) NOT NULL,
    duration_days INT,
    instructions TEXT,
    FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id) ON DELETE CASCADE,
    FOREIGN KEY (medication_id) REFERENCES medications(medication_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: invoices (billing)
-- One-to-Many: patient -> invoices
-- One-to-Many: appointment -> invoices (optional link)
-- ----------------------------------------------------------------
CREATE TABLE invoices (
    invoice_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    appointment_id INT,
    invoice_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    status ENUM('pending','paid','void') NOT NULL DEFAULT 'pending',
    created_by INT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE RESTRICT,
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id) ON DELETE SET NULL,
    FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: invoice_items (invoice line items, links to services or meds)
-- ----------------------------------------------------------------
CREATE TABLE invoice_items (
    invoice_item_id INT AUTO_INCREMENT PRIMARY KEY,
    invoice_id INT NOT NULL,
    description VARCHAR(255) NOT NULL,
    service_id INT,
    medication_id INT,
    quantity INT NOT NULL DEFAULT 1,
    unit_price DECIMAL(12,2) NOT NULL,
    line_total DECIMAL(12,2) GENERATED ALWAYS AS (quantity * unit_price) VIRTUAL,
    FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services(service_id) ON DELETE SET NULL,
    FOREIGN KEY (medication_id) REFERENCES medications(medication_id) ON DELETE SET NULL,
    CHECK (service_id IS NOT NULL OR medication_id IS NOT NULL OR description <> '')
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Table: inventory (for medications stock)
-- ----------------------------------------------------------------
CREATE TABLE inventory (
    inventory_id INT AUTO_INCREMENT PRIMARY KEY,
    medication_id INT NOT NULL UNIQUE,
    quantity_on_hand INT NOT NULL DEFAULT 0,
    reorder_level INT NOT NULL DEFAULT 0,
    last_restock DATE,
    FOREIGN KEY (medication_id) REFERENCES medications(medication_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- Indexes to speed up lookups
-- ----------------------------------------------------------------
CREATE INDEX idx_appointments_patient ON appointments(patient_id);
CREATE INDEX idx_appointments_doctor ON appointments(doctor_id);
CREATE INDEX idx_services_name ON services(name);
CREATE INDEX idx_patients_name ON patients(last_name, first_name);




