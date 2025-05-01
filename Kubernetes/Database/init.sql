CREATE DATABASE projectory;
USE projectory;

-- File Table (moved first because it's referenced early)
CREATE TABLE File (
    fileID INT AUTO_INCREMENT PRIMARY KEY,
    fileName VARCHAR(255) UNIQUE NOT NULL,
    mimeType VARCHAR(100),
    filePath TEXT,
    projectID INT,
    FOREIGN KEY (projectID) REFERENCES Project(projectID) ON DELETE CASCADE
);

-- Account Table
CREATE TABLE Account (
    accountID INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    profilePicFileID INT NULL,
    FOREIGN KEY (profilePicFileID) REFERENCES File(fileID) ON DELETE SET NULL
);

-- User Table
CREATE TABLE User (
    userID INT AUTO_INCREMENT PRIMARY KEY,
    accountID INT,
    FOREIGN KEY (accountID) REFERENCES Account(accountID) ON DELETE CASCADE
);

-- Project Table
CREATE TABLE Project (
    projectID INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    teamLeadID INT,
    FOREIGN KEY (teamLeadID) REFERENCES User(userID) ON DELETE SET NULL
);

-- Team Table
CREATE TABLE Team (
    teamID INT AUTO_INCREMENT PRIMARY KEY,
    projectID INT,
    FOREIGN KEY (projectID) REFERENCES Project(projectID) ON DELETE CASCADE
);

-- TeamHasMember (Many-to-Many Relationship between Team and User)
CREATE TABLE TeamHasMember (
    teamID INT,
    memberID INT,
    PRIMARY KEY (teamID, memberID),
    FOREIGN KEY (teamID) REFERENCES Team(teamID) ON DELETE CASCADE,
    FOREIGN KEY (memberID) REFERENCES User(userID) ON DELETE CASCADE
);

-- Notification Table
CREATE TABLE Notification (
    notificationID INT AUTO_INCREMENT PRIMARY KEY,
    content TEXT NOT NULL,
    projectID INT,
    receivingUserID INT,
    FOREIGN KEY (projectID) REFERENCES Project(projectID) ON DELETE CASCADE,
    FOREIGN KEY (receivingUserID) REFERENCES User(userID) ON DELETE CASCADE
);

-- List Table (To-Do List inside Projects)
CREATE TABLE List (
    listID INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    projectID INT,
    FOREIGN KEY (projectID) REFERENCES Project(projectID) ON DELETE CASCADE
);

-- Task Table
CREATE TABLE Task (
    taskID INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    deadline DATE,
    status ENUM('In Progress', 'Completed') NOT NULL DEFAULT 'In Progress',
    listID INT,
    FOREIGN KEY (listID) REFERENCES List(listID) ON DELETE CASCADE
);

-- MemberHasTask (Many-to-Many Relationship between User and Task)
CREATE TABLE MemberHasTask (
    memberID INT,
    taskID INT,
    PRIMARY KEY (memberID, taskID),
    FOREIGN KEY (memberID) REFERENCES User(userID) ON DELETE CASCADE,
    FOREIGN KEY (taskID) REFERENCES Task(taskID) ON DELETE CASCADE
);

-- Comment Table
CREATE TABLE Comment (
    commentID INT AUTO_INCREMENT PRIMARY KEY,
    value TEXT NOT NULL,
    projectID INT,
    userID INT,
    FOREIGN KEY (projectID) REFERENCES Project(projectID) ON DELETE CASCADE,
    FOREIGN KEY (userID) REFERENCES User(userID) ON DELETE CASCADE
);

-- Audit Trail
CREATE TABLE AuditTrail (
    auditId INT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(50),
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    details VARCHAR(255)
);

-- Triggers
-- user registeration
DELIMITER $$

CREATE TRIGGER trg_after_user_insert
AFTER INSERT ON User
FOR EACH ROW
BEGIN
    INSERT INTO AuditTrail (action, details)
    VALUES (
        'New user added',
        CONCAT('User with ID ', NEW.userID, ' created with AccountID ', NEW.accountID)
    );
END$$

DELIMITER ;

-- project creation
DELIMITER $$

CREATE TRIGGER trg_after_project_insert
AFTER INSERT ON Project
FOR EACH ROW
BEGIN
    INSERT INTO AuditTrail (action, details)
    VALUES (
        'Project Created',
        CONCAT('User with ID ', NEW.teamLeadID, ' created new project with ID ', NEW.projectID)
    );
END$$

DELIMITER ;

-- project deletion
DELIMITER $$

CREATE TRIGGER trg_after_project_delete
AFTER DELETE ON Project
FOR EACH ROW
BEGIN
    INSERT INTO AuditTrail (action, details)
    VALUES (
        'Project Deleted',
        CONCAT('User with ID ', OLD.teamLeadID, ' deleted project with ID ', OLD.projectID)
    );
END$$

DELIMITER ;

-- list creation
DELIMITER $$

CREATE TRIGGER trg_after_list_insert
AFTER INSERT ON List
FOR EACH ROW
BEGIN
    INSERT INTO AuditTrail (action, details)
    VALUES (
        'List Created',
        CONCAT('List with ID ', NEW.listID, ' added to project with ID ', NEW.projectID)
    );
END$$

DELIMITER ;

-- list deleted
DELIMITER $$

CREATE TRIGGER trg_after_list_delete
AFTER DELETE ON List
FOR EACH ROW
BEGIN
    INSERT INTO AuditTrail (action, details)
    VALUES (
        'List Deleted',
        CONCAT('List with ID ', OLD.listID, ' removed from project with ID ', OLD.projectID)
    );
END$$

DELIMITER ;

-- task added
DELIMITER $$

CREATE TRIGGER trg_after_task_insert
AFTER INSERT ON Task
FOR EACH ROW
BEGIN
    DECLARE projID INT;

    SELECT projectID INTO projID
    FROM List
    WHERE listID = NEW.listID;

    INSERT INTO AuditTrail (action, details)
    VALUES (
        'Task Created',
        CONCAT('Task with ID ', NEW.taskID, ' added to list ', NEW.listID, ' in project ', projID)
    );
END$$

DELIMITER ;

-- delete task
DELIMITER $$

CREATE TRIGGER trg_after_task_delete
AFTER DELETE ON Task
FOR EACH ROW
BEGIN
    DECLARE projID INT;

    SELECT projectID INTO projID
    FROM List
    WHERE listID = OLD.listID;

    INSERT INTO AuditTrail (action, details)
    VALUES (
        'Task Deleted',
        CONCAT('Task with ID ', OLD.taskID, ' removed from list ', OLD.listID, ' in project ', projID)
    );
END$$

DELIMITER ;

-- task updation
DELIMITER $$

CREATE TRIGGER trg_after_task_update
AFTER UPDATE ON Task
FOR EACH ROW
BEGIN
    IF NOT (OLD.title <=> NEW.title) THEN
        INSERT INTO AuditTrail (action, details)
        VALUES (
            'Task Title Updated',
            CONCAT('Title of Task with ID ', NEW.taskID, ' was updated from "', OLD.title, '" to "', NEW.title, '"')
        );
    END IF;

    IF NOT (OLD.deadline <=> NEW.deadline) THEN
        INSERT INTO AuditTrail (action, details)
        VALUES (
            'Task Deadline Updated',
            CONCAT('Deadline of Task with ID ', NEW.taskID, ' was updated from "', OLD.deadline, '" to "', NEW.deadline, '"')
        );
    END IF;

    IF NOT (OLD.status <=> NEW.status) THEN
        INSERT INTO AuditTrail (action, details)
        VALUES (
            'Task Status Updated',
            CONCAT('Status of Task with ID ', NEW.taskID, ' was updated from "', OLD.status, '" to "', NEW.status, '"')
        );
    END IF;
END$$

DELIMITER ;

-- create comment
DELIMITER $$

CREATE TRIGGER trg_after_comment_insert
AFTER INSERT ON Comment
FOR EACH ROW
BEGIN
    INSERT INTO AuditTrail (action, details)
    VALUES (
        'Comment Added',
        CONCAT('User with ID ', NEW.userID, ' added comment with ID ', NEW.commentID, ' to project with ID ', NEW.projectID)
    );
END$$

DELIMITER ;

-- file upload

DELIMITER $$

CREATE TRIGGER trg_after_file_insert
AFTER INSERT ON File
FOR EACH ROW
BEGIN
    INSERT INTO AuditTrail (action, details)
    VALUES (
        'File Uploaded',
        CONCAT('File with ID ', NEW.fileID, ' uploaded to project with ID ', NEW.projectID)
    );
END$$

DELIMITER ;

-- team creation
DELIMITER $$

CREATE TRIGGER trg_after_team_insert
AFTER INSERT ON Team
FOR EACH ROW
BEGIN
    INSERT INTO AuditTrail (action, details)
    VALUES (
        'Team Created',
        CONCAT('Team with ID ', NEW.teamID, ' created for project with ID ')
    );
END$$

DELIMITER ;

-- Team member added
DELIMITER $$

CREATE TRIGGER trg_after_member_added_to_team
AFTER INSERT ON TeamHasMember
FOR EACH ROW
BEGIN
    DECLARE teamLeadID INT;

    -- Get team lead ID by joining Team and Project tables
    SELECT p.teamLeadID INTO teamLeadID
    FROM Team t
    JOIN Project p ON t.projectID = p.projectID
    WHERE t.teamID = NEW.teamID;

    INSERT INTO AuditTrail (action, details)
    VALUES (
        'Member Added to Team',
        CONCAT('Member with ID ', NEW.memberID, ' added to team with ID ', NEW.teamID, ' by team lead with ID ', teamLeadID)
    );
END$$

DELIMITER ;

-- team member removed
DELIMITER $$

CREATE TRIGGER trg_after_member_removed_from_team
AFTER DELETE ON TeamHasMember
FOR EACH ROW
BEGIN
    DECLARE teamLeadID INT;

    -- Get team lead ID by joining Team and Project tables
    SELECT p.teamLeadID INTO teamLeadID
    FROM Team t
    JOIN Project p ON t.projectID = p.projectID
    WHERE t.teamID = OLD.teamID;

    INSERT INTO AuditTrail (action, details)
    VALUES (
        'Member Removed from Team',
        CONCAT('Member with ID ', OLD.memberID, ' removed from team with ID ', OLD.teamID, ' by team lead with ID ', teamLeadID)
    );
END$$

DELIMITER ;