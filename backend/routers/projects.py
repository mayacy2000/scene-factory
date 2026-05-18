from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from database import get_db
import models as m
import schemas as s
from services import storage_service

router = APIRouter(prefix="/projects", tags=["projects"])


@router.get("", response_model=List[s.ProjectOut])
def list_projects(db: Session = Depends(get_db)):
    return db.query(m.Project).order_by(m.Project.updated_at.desc()).all()


@router.post("", response_model=s.ProjectOut, status_code=status.HTTP_201_CREATED)
def create_project(body: s.ProjectCreate, db: Session = Depends(get_db)):
    project = m.Project(**body.model_dump())
    db.add(project)
    db.flush()

    folder_path = storage_service.init_project_folder(project.id, project.title)
    project.folder_path = folder_path
    project.status = "in_progress"

    db.commit()
    db.refresh(project)
    return project


@router.get("/{project_id}", response_model=s.ProjectOut)
def get_project(project_id: str, db: Session = Depends(get_db)):
    proj = db.query(m.Project).filter(m.Project.id == project_id).first()
    if not proj:
        raise HTTPException(404, "Project not found")
    return proj


@router.put("/{project_id}", response_model=s.ProjectOut)
def update_project(project_id: str, body: s.ProjectUpdate, db: Session = Depends(get_db)):
    proj = db.query(m.Project).filter(m.Project.id == project_id).first()
    if not proj:
        raise HTTPException(404, "Project not found")
    for field, val in body.model_dump(exclude_none=True).items():
        setattr(proj, field, val)
    db.commit()
    db.refresh(proj)
    return proj


@router.delete("/{project_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_project(project_id: str, db: Session = Depends(get_db)):
    proj = db.query(m.Project).filter(m.Project.id == project_id).first()
    if not proj:
        raise HTTPException(404, "Project not found")
    storage_service.delete_project_folder(project_id)
    db.delete(proj)
    db.commit()
